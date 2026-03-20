DROP PROCEDURE IF EXISTS spSplitPlant;

DELIMITER //

CREATE PROCEDURE spSplitPlant(
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
    DECLARE vChildPlantId INT;
    DECLARE vChildPlantTag CHAR(8);
    DECLARE vPlantName VARCHAR(100);

    DECLARE i INT DEFAULT 0;

    IF pSplitDateTime IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SplitDateTime is required';
    END IF;

    IF JSON_LENGTH(pChildrenJson) < 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A split must create at least two child plants';
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
    JOIN taxon t ON t.taxonId = p.taxonId
    JOIN genus g ON g.genusId = t.genusId
    WHERE p.plantId = pParentPlantId
      AND p.isActive = 1
    FOR UPDATE;

    IF vParentPlantTag IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant not found or inactive';
    END IF;

    IF vParentEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant already ended';
    END IF;

    IF vTaxonIsActive = 0 OR vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant must be classified under an active genus and species / hybrid before splitting';
    END IF;

    IF pSplitDateTime < vParentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SplitDateTime cannot be before plant lifecycle start';
    END IF;

    IF EXISTS (
        SELECT 1 FROM plantsplit
        WHERE parentPlantId = pParentPlantId
          AND isActive = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant has already been split';
    END IF;

    INSERT INTO plantsplit(
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

    WHILE i < vChildCount DO

        SET vPlantName =
            JSON_UNQUOTE(JSON_EXTRACT(pChildrenJson, CONCAT('$[', i, '].plantName')));

        CALL spAddPlant(
            vTaxonId,
            pSplitDateTime,
            CONCAT('From split of ', vParentPlantTag),
            vPlantName,
            NULL
        );

        SET vChildPlantId = LAST_INSERT_ID();

        INSERT INTO plantsplitchild(
            plantSplitId,
            childPlantId,
            isActive
        )
        VALUES (
            vSplitId,
            vChildPlantId,
            1
        );

        SET i = i + 1;

    END WHILE;

    UPDATE plantlocationhistory
    SET endDateTime = pSplitDateTime
    WHERE plantId = pParentPlantId
      AND endDateTime IS NULL
      AND isActive = 1;

    UPDATE plant
    SET endDate = pSplitDateTime,
        endReasonCode = 'Split',
        endNotes = CONCAT(
            'Split into ', vChildCount,
            ' plants on ',
            DATE_FORMAT(pSplitDateTime, '%Y-%m-%d %H:%i:%s')
        )
    WHERE plantId = pParentPlantId;

    COMMIT;

END //

DELIMITER ;