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
            ROLLBACK TO SAVEPOINT orchidapp_moveplanttolocation;
            RELEASE SAVEPOINT orchidapp_moveplanttolocation;
        END IF;
        RESIGNAL;
    END;
    IF @@in_transaction THEN
        SAVEPOINT orchidapp_moveplanttolocation;
        SET vSavepointCreated = TRUE;
    ELSE
        START TRANSACTION;
        SET vOwnTransaction = TRUE;
    END IF;
    SELECT plantId, endDate, acquisitionDate
      INTO vLockedPlantId, vLockedEnd, vLockedAcquisition
      FROM plant WHERE plantId = pPlantId AND isActive = 1 FOR UPDATE;
    IF vLockedPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active plant not found.';
    END IF;
    IF vLockedEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ended plants are read-only.';
    END IF;
    IF pStartDate IS NULL OR pStartDate > CURRENT_DATE
       OR (vLockedAcquisition IS NOT NULL AND pStartDate < DATE(vLockedAcquisition)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Move date must be within the plant lifecycle and not in the future.';
    END IF;
    SET vNow = NOW();
    SET vStart = TIMESTAMP(DATE(pStartDate), TIME(vNow));
    IF NOT EXISTS (SELECT 1 FROM plant WHERE plantId = pPlantId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PlantId does not exist.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM location WHERE locationId = pLocationId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LocationId does not exist.';
    END IF;
    IF (SELECT COUNT(*) FROM plantlocationhistory WHERE plantId = pPlantId
          AND isActive = 1 AND endDateTime IS NULL FOR UPDATE) > 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invariant violation: multiple current locations.';
    END IF;
    SELECT plantLocationHistoryId, locationId, startDateTime
      INTO vCurrentId, vCurrentLocationId, vCurrentStart
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1
      AND endDateTime IS NULL
    LIMIT 1 FOR UPDATE;
    IF vCurrentId IS NOT NULL AND vCurrentLocationId = pLocationId THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant is already in this location.';
    END IF;
    IF vCurrentId IS NOT NULL AND vStart <= vCurrentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move start must be after current location start.';
    END IF;
    SELECT MAX(COALESCE(endDateTime, startDateTime))
      INTO vLatestPoint
    FROM plantlocationhistory
    WHERE plantId = pPlantId
      AND isActive = 1 FOR UPDATE;
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
      AND COALESCE(endDateTime, '9999-12-31') > vStart FOR UPDATE;
    IF vOverlapCount > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Move would overlap existing history.';
    END IF;
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
    IF vOwnTransaction THEN
        COMMIT;
    ELSE
        RELEASE SAVEPOINT orchidapp_moveplanttolocation;
    END IF;
END
//

DELIMITER ;
