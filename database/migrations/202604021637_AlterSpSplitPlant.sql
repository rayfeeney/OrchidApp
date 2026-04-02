DROP PROCEDURE IF EXISTS spSplitPlant;

DELIMITER //

CREATE  PROCEDURE  `spSplitPlant`(
    IN pParentPlantId INT,
    IN pSplitDateTime DATETIME,
    IN pChildrenJson JSON,
    IN pSplitReasonNotes TEXT,
    IN pSplitNotes TEXT
)
BEGIN
    DECLARE vTaxonId INT;
    DECLARE vParentPlantTag CHAR(8);
    DECLARE vParentStart DATETIME;
    DECLARE vParentEnd DATETIME;
    DECLARE vTaxonIsActive TINYINT;
    DECLARE vGenusIsActive TINYINT;

    DECLARE vSplitId INT;
    DECLARE vChildCount INT;
    DECLARE vIdx INT DEFAULT 0;

    DECLARE vChildName VARCHAR(100);
    DECLARE vMediumIdText VARCHAR(20);
    DECLARE vMediumId INT;
    DECLARE vChildTag CHAR(8);
    DECLARE vChildPlantId INT;

    
    
    

    IF pParentPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant id is required';
    END IF;

    IF pSplitDateTime IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SplitDateTime is required';
    END IF;

    IF DATE(pSplitDateTime) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Split date cannot be in the future';
    END IF;

    IF JSON_LENGTH(pChildrenJson) < 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Split must create at least two child plants';
    END IF;

    START TRANSACTION;

    SELECT
        p.taxonId,
        p.plantTag,
        p.acquisitionDate,
        p.endDate,
        t.isActive,
        g.isActive
    INTO
        vTaxonId,
        vParentPlantTag,
        vParentStart,
        vParentEnd,
        vTaxonIsActive,
        vGenusIsActive
    FROM plant p
    JOIN taxon t ON p.taxonId = t.taxonId
    JOIN genus g ON t.genusId = g.genusId
    WHERE p.plantId = pParentPlantId
      AND p.isActive = 1
    FOR UPDATE;

    IF vParentEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant already ended';
    END IF;

    IF vTaxonIsActive = 0 OR vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant must be classified under an active genus and species / hybrid';
    END IF;

    IF pSplitDateTime < vParentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Split datetime cannot be before plant lifecycle start';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM plantsplit
        WHERE parentPlantId = pParentPlantId
          AND isActive = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant has already been split';
    END IF;

    
    
    

    INSERT INTO plantsplit (
        parentPlantId,
        splitDateTime,
        splitReasonNotes,
        splitNotes,
        isActive
    )
    VALUES (
        pParentPlantId,
        pSplitDateTime,
        pSplitReasonNotes,
        pSplitNotes,
        1
    );

    SET vSplitId = LAST_INSERT_ID();
    SET vChildCount = JSON_LENGTH(pChildrenJson);

    
    
    DROP TEMPORARY TABLE IF EXISTS tmpChildren;    

    CREATE TEMPORARY TABLE tmpChildren (
        childPlantId INT,
        childPlantTag CHAR(8)
    );

    WHILE vIdx < vChildCount DO

        SET vChildName = JSON_UNQUOTE(
            JSON_EXTRACT(pChildrenJson, CONCAT('$[', vIdx, '].plantName'))
        );

        IF vChildName IS NOT NULL THEN
            SET vChildName = TRIM(vChildName);

            IF vChildName = '' OR LOWER(vChildName) = 'null' THEN
                SET vChildName = NULL;
            END IF;
        END IF;

        SET vMediumIdText = JSON_UNQUOTE(
            JSON_EXTRACT(
                pChildrenJson,
                CONCAT('$[', vIdx, '].mediumId')
            )
        );

        IF vMediumIdText IS NULL OR vMediumIdText = 'null' THEN
            SET vMediumId = NULL;
        ELSE
            SET vMediumId = CAST(vMediumIdText AS UNSIGNED);
        END IF;

        SET vChildTag = fnGeneratePlantTag();

        INSERT INTO plant (
            taxonId,
            plantTag,
            plantName,
            acquisitionDate,
            acquisitionSource,
            isActive
        )
        VALUES (
            vTaxonId,
            vChildTag,
            vChildName,
            pSplitDateTime,
            CONCAT('Split from ', vParentPlantTag),
            1
        );

        SET vChildPlantId = LAST_INSERT_ID();

        IF vMediumId IS NOT NULL THEN

            INSERT INTO repotting (
                plantId,
                repotDate,
                newGrowthMediumId,
                notes,
                isActive
            )
            VALUES (
                vChildPlantId,
                pSplitDateTime,
                vMediumId,
                'Initial medium from split',
                1
            );

        END IF;

        INSERT INTO plantsplitchild (
            plantSplitId,
            childPlantId,
            isActive
        )
        VALUES (
            vSplitId,
            vChildPlantId,
            1
        );

        INSERT INTO tmpChildren VALUES (vChildPlantId, vChildTag);

        SET vIdx = vIdx + 1;

    END WHILE;

    
    
    -- Only close lifecycle rows if transitioning from active → ended
    IF vParentEnd IS NULL THEN    

        UPDATE plantlocationhistory
        SET endDateTime = pSplitDateTime
        WHERE plantId = pParentPlantId
        AND endDateTime IS NULL
        AND isActive = 1;

        UPDATE flowering
        SET endDate = pSplitDateTime
        WHERE plantId = pParentPlantId
        AND endDate IS NULL
        AND isActive = 1;

    END IF;

    UPDATE plant
    SET endDate = pSplitDateTime,
        endNotes = CONCAT(
            'Split into ',
            vChildCount,
            ' plants on ',
            DATE_FORMAT(pSplitDateTime, '%Y-%m-%d %H:%i:%s')
        )
    WHERE plantId = pParentPlantId;


    SELECT childPlantId, childPlantTag
    FROM tmpChildren;

    DROP TEMPORARY TABLE tmpChildren;

    COMMIT;

END //

DELIMITER ;