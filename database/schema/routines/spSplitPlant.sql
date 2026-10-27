SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spSplitPlant`(
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
    DECLARE vOwnTransaction BOOLEAN DEFAULT FALSE;
    DECLARE vSavepointCreated BOOLEAN DEFAULT FALSE;
    DECLARE vLockedPlantId INT;
    DECLARE vLockedEnd DATETIME;
    DECLARE vLockedAcquisition DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF vOwnTransaction THEN
            ROLLBACK;
        ELSEIF vSavepointCreated AND @@in_transaction THEN
            ROLLBACK TO SAVEPOINT orchidapp_splitplant;
            RELEASE SAVEPOINT orchidapp_splitplant;
        END IF;
        DROP TEMPORARY TABLE IF EXISTS orchidapp_split_children;
        RESIGNAL;
    END;
    IF @@in_transaction THEN
        SAVEPOINT orchidapp_splitplant;
        SET vSavepointCreated = TRUE;
    ELSE
        START TRANSACTION;
        SET vOwnTransaction = TRUE;
    END IF;
    SELECT plantId, endDate, acquisitionDate
      INTO vLockedPlantId, vLockedEnd, vLockedAcquisition
      FROM plant WHERE plantId = pParentPlantId AND isActive = 1 FOR UPDATE;
    IF vLockedPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active plant not found.';
    END IF;
    IF vLockedEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ended plants are read-only.';
    END IF;
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
    IF pChildrenJson IS NULL OR JSON_TYPE(pChildrenJson) <> 'ARRAY' OR JSON_LENGTH(pChildrenJson) < 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Split must create at least two child plants';
    END IF;
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
          AND isActive = 1 FOR UPDATE
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant has already been split';
    END IF;
    IF EXISTS (SELECT 1 FROM flowering WHERE plantId = pParentPlantId
                   AND isActive = 1 AND endDate IS NULL AND startDate > pSplitDateTime FOR UPDATE)
       OR EXISTS (SELECT 1 FROM plantlocationhistory WHERE plantId = pParentPlantId
                   AND isActive = 1 AND endDateTime IS NULL AND startDateTime >= pSplitDateTime FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Split cannot precede an open interval start.';
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
    DROP TEMPORARY TABLE IF EXISTS orchidapp_split_children;
    CREATE TEMPORARY TABLE orchidapp_split_children (
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
        IF EXISTS (
            SELECT 1
            FROM plantpropagation
            WHERE childPlantId = vChildPlantId
            AND isActive = 1
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Plant already has a propagation origin';
        END IF;
        IF vMediumId IS NOT NULL THEN
            INSERT INTO repotting (
                plantId,
                repotDate,
                newGrowthMediumId,
                repotReasonNotes,
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
        INSERT INTO orchidapp_split_children VALUES (vChildPlantId, vChildTag);
        SET vIdx = vIdx + 1;
    END WHILE;
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
            DATE_FORMAT(pSplitDateTime, '%d/%m/%Y')
        )
    WHERE plantId = pParentPlantId;
    IF vOwnTransaction THEN
        COMMIT;
    ELSE
        RELEASE SAVEPOINT orchidapp_splitplant;
    END IF;
    SELECT childPlantId, childPlantTag
    FROM orchidapp_split_children;
    DROP TEMPORARY TABLE orchidapp_split_children;

END
//

DELIMITER ;
