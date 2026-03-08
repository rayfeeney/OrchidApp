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
            moveReasonNotes    = COALESCE(pMoveReasonNotes, moveReasonNotes),
            plantLocationNotes = COALESCE(pPlantLocationNotes, plantLocationNotes)
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

