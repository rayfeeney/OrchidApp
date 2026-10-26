SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spMovePlantToLocation`(
    IN pPlantId INT,
    IN pLocationId INT,
    IN pStartDate DATE,

    IN pMoveReasonNotes VARCHAR(500),
    IN pPlantLocationNotes VARCHAR(500)
)
BEGIN
    DECLARE vStart DATETIME;
    DECLARE vNow DATETIME;

    DECLARE vCurrentId INT;
    DECLARE vCurrentLocationId INT;
    DECLARE vCurrentStart DATETIME;

    DECLARE vLatestPoint DATETIME;
    DECLARE vOverlapCount INT;

    SET vNow = NOW();
    SET vStart = TIMESTAMP(DATE(pStartDate), TIME(vNow));

    IF NOT EXISTS (SELECT 1 FROM plant WHERE plantId = pPlantId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PlantId does not exist.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM location WHERE locationId = pLocationId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LocationId does not exist.';
    END IF;

    SELECT plantLocationHistoryId, locationId, startDateTime
      INTO vCurrentId, vCurrentLocationId, vCurrentStart
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1
      AND endDateTime IS NULL
    LIMIT 1;

    IF vCurrentId IS NOT NULL AND vCurrentLocationId = pLocationId THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant is already in this location.';
    END IF;

    IF vCurrentId IS NOT NULL AND vStart < vCurrentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move start cannot be earlier than current location start.';
    END IF;

    SELECT MAX(COALESCE(endDateTime, startDateTime))
      INTO vLatestPoint
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1;

    IF vLatestPoint IS NOT NULL AND vStart < vLatestPoint THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move would backdate into existing history.';
    END IF;

    SELECT COUNT(*) INTO vOverlapCount
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1
      AND plantLocationHistoryId <> COALESCE(vCurrentId, -1)
      AND startDateTime < vStart
      AND COALESCE(endDateTime, '9999-12-31') > vStart;

    IF vOverlapCount > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move would overlap existing history.';
    END IF;

    START TRANSACTION;

        IF vCurrentId IS NOT NULL THEN
            UPDATE plantlocationhistory
            SET endDateTime = vStart
            WHERE plantLocationHistoryId = vCurrentId
              AND isActive = 1
              AND endDateTime IS NULL;
        END IF;

        INSERT INTO plantlocationhistory (
            plantId,
            locationId,
            startDateTime,
            endDateTime,

            moveReasonNotes,
            plantLocationNotes,
            isActive
        )
        VALUES (
            pPlantId,
            pLocationId,
            vStart,
            NULL,

            pMoveReasonNotes,
            pPlantLocationNotes,
            1
        );

    COMMIT;
END
//

DELIMITER ;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spEditPlantLocation`(
    IN pPlantLocationHistoryId INT,
    IN pNewStartDateTime DATETIME,
    IN pMoveReasonNotes VARCHAR(500),
    IN pPlantLocationNotes VARCHAR(500)
)
BEGIN
    DECLARE vPlantId INT;
    DECLARE vOldStart DATETIME;
    DECLARE vOldEnd DATETIME;
    DECLARE vIsCurrent TINYINT;

    DECLARE vPrevId INT;
    DECLARE vPrevStart DATETIME;

    DECLARE vNextStart DATETIME;

    DECLARE vNewStart DATETIME;
    DECLARE vEffectiveEnd DATETIME;

    START TRANSACTION;

        SELECT plantId, startDateTime, endDateTime
          INTO vPlantId, vOldStart, vOldEnd
        FROM plantlocationhistory
        WHERE plantLocationHistoryId = pPlantLocationHistoryId
          AND isActive = 1
        FOR UPDATE;

        IF vPlantId IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Active location history row not found.';
        END IF;

        SET vIsCurrent = IF(vOldEnd IS NULL, 1, 0);
        SET vNewStart = COALESCE(pNewStartDateTime, vOldStart);
        SET vEffectiveEnd = IF(vIsCurrent = 1, NOW(), vOldEnd);

        IF vNewStart >= vEffectiveEnd THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime must be earlier than endDateTime.';
        END IF;

        SELECT plantLocationHistoryId, startDateTime
          INTO vPrevId, vPrevStart
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND endDateTime = vOldStart
          AND plantLocationHistoryId <> pPlantLocationHistoryId
        FOR UPDATE;

        SELECT startDateTime
          INTO vNextStart
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND startDateTime > vOldStart
        ORDER BY startDateTime
        LIMIT 1
        FOR UPDATE;

        IF vNextStart IS NOT NULL AND vNewStart >= vNextStart THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime cannot overlap next location.';
        END IF;

        IF vIsCurrent = 1 AND vNewStart >= NOW() THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime cannot be in the future.';
        END IF;

        IF vPrevId IS NOT NULL AND vNewStart <= vPrevStart THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime would invalidate previous location.';
        END IF;

        IF vPrevId IS NOT NULL AND vNewStart <> vOldStart THEN
            UPDATE plantlocationhistory
            SET endDateTime = vNewStart
            WHERE plantLocationHistoryId = vPrevId;
        END IF;

        UPDATE plantlocationhistory
        SET
            startDateTime      = vNewStart,
            moveReasonNotes    = NULLIF(pMoveReasonNotes, ''),
            plantLocationNotes = NULLIF(pPlantLocationNotes, '')
        WHERE plantLocationHistoryId = pPlantLocationHistoryId;

        IF (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND endDateTime IS NULL
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple current locations.';
        END IF;

    COMMIT;
END
//

DELIMITER ;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spRemovePlantLocation`(
    IN pPlantLocationHistoryId INT
)
BEGIN
    DECLARE vPlantId INT;
    DECLARE vStart DATETIME;
    DECLARE vEnd DATETIME;
    DECLARE vIsCurrent TINYINT;

    DECLARE vPrevId INT;
    DECLARE vNextId INT;

    START TRANSACTION;

        SELECT plantId, startDateTime, endDateTime
          INTO vPlantId, vStart, vEnd
        FROM plantlocationhistory
        WHERE plantLocationHistoryId = pPlantLocationHistoryId
          AND isActive = 1
        FOR UPDATE;

        IF vPlantId IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Active location history row not found.';
        END IF;

        SET vIsCurrent = IF(vEnd IS NULL, 1, 0);

        IF (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND endDateTime = vStart
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ambiguous previous location during removal.';
        END IF;

        SELECT plantLocationHistoryId
          INTO vPrevId
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND endDateTime = vStart
        LIMIT 1;

        IF vIsCurrent = 0 AND (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND startDateTime = vEnd
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ambiguous next location during removal.';
        END IF;

        IF vIsCurrent = 0 THEN
            SELECT plantLocationHistoryId
              INTO vNextId
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND startDateTime = vEnd
            LIMIT 1;
        END IF;

        UPDATE plantlocationhistory
        SET isActive = 0
        WHERE plantLocationHistoryId = pPlantLocationHistoryId;

        IF vIsCurrent = 1 THEN
            IF vPrevId IS NOT NULL THEN
                UPDATE plantlocationhistory
                SET endDateTime = NULL
                WHERE plantLocationHistoryId = vPrevId;
            END IF;
        ELSE
            IF vPrevId IS NOT NULL AND vNextId IS NOT NULL THEN
                UPDATE plantlocationhistory
                SET endDateTime = vEnd
                WHERE plantLocationHistoryId = vPrevId;
            END IF;
        END IF;

        IF (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND endDateTime IS NULL
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation after location removal.';
        END IF;

    COMMIT;
END
//

DELIMITER ;

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

        INSERT INTO tmpChildren VALUES (vChildPlantId, vChildTag);

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

    SELECT childPlantId, childPlantTag

    FROM tmpChildren;

    DROP TEMPORARY TABLE tmpChildren;

    COMMIT;

END
//

DELIMITER ;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spPropagatePlant`(

    IN pParentPlantId INT,
    IN pPropagationDate DATE,
    IN pPropagationTypeId INT,
    IN pChildPlantName VARCHAR(100),
    IN pMediumId INT,
    IN pPropagationNotes TEXT

)
BEGIN

    DECLARE vTaxonId INT;
    DECLARE vParentPlantTag CHAR(8);
    DECLARE vParentStart DATETIME;
    DECLARE vParentEnd DATETIME;
    DECLARE vTaxonIsActive TINYINT;
    DECLARE vGenusIsActive TINYINT;

    DECLARE vChildTag CHAR(8);
    DECLARE vChildPlantId INT;

    DECLARE vPropagationDateTime DATETIME;
    DECLARE vPropagationTypeName VARCHAR(100);

    IF pParentPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant id is required';
    END IF;

    IF pPropagationDate IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation date is required';
    END IF;

    IF pPropagationTypeId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation type is required';
    END IF;

    IF pPropagationDate > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation date cannot be in the future';
    END IF;

    SET vPropagationDateTime = TIMESTAMP(
        pPropagationDate,
        TIME(NOW())
    );

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

    IF vPropagationDateTime < vParentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation datetime cannot be before plant lifecycle start';
    END IF;

    SELECT propagationTypeName
    INTO vPropagationTypeName
    FROM propagationtype
    WHERE propagationTypeId = pPropagationTypeId
    AND isActive = 1;

    IF vPropagationTypeName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid propagation type';
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
        pChildPlantName,
        vPropagationDateTime,
        CONCAT(vPropagationTypeName, ' from ', vParentPlantTag),
        1
    );

    SET vChildPlantId = LAST_INSERT_ID();

    IF EXISTS (
        SELECT 1
        FROM plantsplitchild
        WHERE childPlantId = vChildPlantId
        AND isActive = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant already has a split origin';
    END IF;

    IF pMediumId IS NOT NULL THEN
        INSERT INTO repotting (
            plantId,
            repotDate,
            newGrowthMediumId,
            repotReasonNotes,
            isActive
        )
        VALUES (
            vChildPlantId,
            vPropagationDateTime,
            pMediumId,
            'Initial medium from propagation',
            1
        );
    END IF;

    INSERT INTO plantpropagation (
        parentPlantId,
        childPlantId,
        propagationTypeId,
        propagationDateTime,
        propagationNotes,
        isActive
    )
    VALUES (
        pParentPlantId,
        vChildPlantId,
        pPropagationTypeId,
        vPropagationDateTime,
        pPropagationNotes,
        1
    );

    SELECT
        vChildPlantId AS childPlantId,
        vChildTag AS childPlantTag;

    COMMIT;

END
//

DELIMITER ;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spSetHeroPhoto`(
    IN pPlantId INT,
    IN pPlantPhotoId INT
)
BEGIN

    DECLARE vExists INT;

    SELECT COUNT(*)
    INTO vExists
    FROM orchids.plantphoto
    WHERE plantPhotoId = pPlantPhotoId
      AND plantId = pPlantId
      AND isActive = 1;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid hero selection';
    END IF;

    UPDATE orchids.plantphoto
    SET isHero = 0
    WHERE plantId = pPlantId
      AND isHero = 1
      AND isActive = 1;

    UPDATE orchids.plantphoto
    SET isHero = 1
    WHERE plantPhotoId = pPlantPhotoId;

END
//

DELIMITER ;
