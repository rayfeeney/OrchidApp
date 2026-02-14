DELIMITER //
CREATE OR REPLACE PROCEDURE `spMovePlantToLocation`(
    IN pPlantId INT,
    IN pLocationId INT,
    IN pStartDate DATE,
--    IN pMoveReasonCode VARCHAR(30),
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

    /* ---------- Guards ---------- */

    IF NOT EXISTS (SELECT 1 FROM plant WHERE plantId = pPlantId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PlantId does not exist.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM location WHERE locationId = pLocationId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LocationId does not exist.';
    END IF;

    /* Current active open row */
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

    /* ---------- Transaction ---------- */

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
--            moveReasonCode,
            moveReasonNotes,
            plantLocationNotes,
            isActive
        )
        VALUES (
            pPlantId,
            pLocationId,
            vStart,
            NULL,
--            pMoveReasonCode,
            pMoveReasonNotes,
            pPlantLocationNotes,
            1
        );

    COMMIT;
END
//
DELIMITER ;

