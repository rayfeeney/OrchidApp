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
            ROLLBACK TO SAVEPOINT orchidapp_editplantlocation;
            RELEASE SAVEPOINT orchidapp_editplantlocation;
        END IF;
        RESIGNAL;
    END;
    IF @@in_transaction THEN
        SAVEPOINT orchidapp_editplantlocation;
        SET vSavepointCreated = TRUE;
    ELSE
        START TRANSACTION;
        SET vOwnTransaction = TRUE;
    END IF;
    SELECT plantId INTO vPlantId FROM plantlocationhistory
     WHERE plantLocationHistoryId = pPlantLocationHistoryId AND isActive = 1;
    SELECT plantId, endDate, acquisitionDate
      INTO vLockedPlantId, vLockedEnd, vLockedAcquisition
      FROM plant WHERE plantId = vPlantId AND isActive = 1 FOR UPDATE;
    IF vLockedPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active plant not found.';
    END IF;
    IF vLockedEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ended plants are read-only.';
    END IF;
        SET vPlantId = NULL;
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
        IF DATE(vNewStart) > CURRENT_DATE OR
           (vLockedAcquisition IS NOT NULL AND DATE(vNewStart) < DATE(vLockedAcquisition)) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Location date must be within the plant lifecycle and not in the future.';
        END IF;
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
        IF EXISTS (SELECT 1 FROM plantlocationhistory
             WHERE plantId = vPlantId AND isActive = 1
               AND plantLocationHistoryId <> pPlantLocationHistoryId
               AND plantLocationHistoryId <> COALESCE(vPrevId, -1)
               AND startDateTime < COALESCE(vOldEnd, '9999-12-31')
               AND COALESCE(endDateTime, '9999-12-31') > vNewStart FOR UPDATE) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Location edit would overlap existing history.';
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
              AND endDateTime IS NULL FOR UPDATE
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple current locations.';
        END IF;
    IF vOwnTransaction THEN
        COMMIT;
    ELSE
        RELEASE SAVEPOINT orchidapp_editplantlocation;
    END IF;
END
//

DELIMITER ;
