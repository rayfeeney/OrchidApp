DELIMITER //
CREATE OR REPLACE PROCEDURE `spSplitPlant`(
    IN pParentPlantId INT,
    IN pSplitDateTime DATETIME,
    IN pChildPlantTagsCsv TEXT,
    IN pSplitReasonCode VARCHAR(30),
    IN pSplitReasonNotes TEXT,
    IN pSplitNotes TEXT
)
BEGIN
    DECLARE vTaxonId INT;
    DECLARE vParentStart DATETIME;
    DECLARE vParentEnd DATETIME;

    DECLARE vSplitId INT;

    DECLARE vRemaining TEXT;
    DECLARE vToken TEXT;
    DECLARE vCommaPos INT;
    DECLARE vChildTag VARCHAR(100);

    DECLARE vChildCount INT DEFAULT 0;

    DECLARE vErrorMessage VARCHAR(255);

    IF pSplitDateTime IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SplitDateTime is required';
    END IF;

    START TRANSACTION;

    
    SELECT taxonId, startDateTime, endDateTime
      INTO vTaxonId, vParentStart, vParentEnd
    FROM plant
    WHERE plantId = pParentPlantId
      AND isActive = 1
    FOR UPDATE;

    IF vTaxonId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parent plant not found or inactive';
    END IF;

    IF vParentEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parent plant already ended';
    END IF;

    IF pSplitDateTime < vParentStart THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SplitDateTime cannot be before plant startDateTime';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM plantsplit
        WHERE parentPlantId = pParentPlantId
          AND isActive = 1
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plant has already been split';
    END IF;

    
    CREATE TEMPORARY TABLE tmpSplitTags (
        tag VARCHAR(100) NOT NULL,
        PRIMARY KEY (tag)
    );

    SET vRemaining = TRIM(COALESCE(pChildPlantTagsCsv, ''));

    IF vRemaining = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'At least two child plant tags are required';
    END IF;

    parse_loop: LOOP

        SET vCommaPos = LOCATE(',', vRemaining);

        IF vCommaPos = 0 THEN
            SET vToken = vRemaining;
            SET vRemaining = '';
        ELSE
            SET vToken = SUBSTRING(vRemaining, 1, vCommaPos - 1);
            SET vRemaining = SUBSTRING(vRemaining, vCommaPos + 1);
        END IF;

        SET vChildTag = TRIM(vToken);

        IF vChildTag = '' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Child plant tag cannot be empty';
        END IF;

        
        IF EXISTS (SELECT 1 FROM tmpSplitTags WHERE tag = vChildTag) THEN
                SET vErrorMessage = CONCAT('Duplicate child tag in split request: ', vChildTag);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = vErrorMessage;
        END IF;

        
        IF EXISTS (SELECT 1 FROM plant WHERE plantTag = vChildTag) THEN
                SET vErrorMessage = CONCAT('Plant tag already exists: ', vChildTag);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = vErrorMessage;
        END IF;

        INSERT INTO tmpSplitTags(tag) VALUES (vChildTag);

        IF vRemaining = '' THEN
            LEAVE parse_loop;
        END IF;

    END LOOP;

    SELECT COUNT(*) INTO vChildCount FROM tmpSplitTags;

    IF vChildCount < 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A split must create at least two child plants';
    END IF;

    
    INSERT INTO plantsplit (
        parentPlantId,
        splitDateTime,
        splitReasonCode,
        splitReasonNotes,
        splitNotes,
        isActive
    )
    VALUES (
        pParentPlantId,
        pSplitDateTime,
        pSplitReasonCode,
        pSplitReasonNotes,
        pSplitNotes,
        1
    );

    SET vSplitId = LAST_INSERT_ID();

    
    BEGIN
        DECLARE done INT DEFAULT 0;
        DECLARE curTag VARCHAR(100);
        DECLARE curChildPlantId INT;

        DECLARE tagCur CURSOR FOR
            SELECT tag FROM tmpSplitTags;

        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

        OPEN tagCur;

        child_loop: LOOP
            FETCH tagCur INTO curTag;
            IF done = 1 THEN
                LEAVE child_loop;
            END IF;

            INSERT INTO plant (
                taxonId,
                plantTag,
                startDateTime,
                endDateTime,
                isActive
            )
            VALUES (
                vTaxonId,
                curTag,
                pSplitDateTime,
                NULL,
                1
            );

            SET curChildPlantId = LAST_INSERT_ID();

            INSERT INTO plantsplitchild (
                plantSplitId,
                childPlantId,
                isActive
            )
            VALUES (
                vSplitId,
                curChildPlantId,
                1
            );
        END LOOP;

        CLOSE tagCur;
    END;

    
    UPDATE plant
    SET endDateTime = pSplitDateTime
    WHERE plantId = pParentPlantId;

    DROP TEMPORARY TABLE tmpSplitTags;

    COMMIT;
END
//
DELIMITER ;

