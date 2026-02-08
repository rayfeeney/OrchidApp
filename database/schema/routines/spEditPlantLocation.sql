DELIMITER //
CREATE PROCEDURE `spEditPlantLocation`(
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

        /* --- Load + lock target row --- */
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

        /* --- Guard: start must be before end / NOW --- */
        IF vNewStart >= vEffectiveEnd THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime must be earlier than endDateTime.';
        END IF;

        /* --- Load previous row (immediate predecessor) --- */
        SELECT plantLocationHistoryId, startDateTime
          INTO vPrevId, vPrevStart
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND endDateTime = vOldStart
          AND plantLocationHistoryId <> pPlantLocationHistoryId
        FOR UPDATE;

        /* --- Load next row (immediate successor) --- */
        SELECT startDateTime
          INTO vNextStart
        FROM plantlocationhistory
        WHERE plantId = vPlantId
          AND isActive = 1
          AND startDateTime > vOldStart
        ORDER BY startDateTime
        LIMIT 1
        FOR UPDATE;

        /* --- Guard: must not overlap next row --- */
        IF vNextStart IS NOT NULL AND vNewStart >= vNextStart THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime cannot overlap next location.';
        END IF;

        /* --- Guard: current row cannot move into the future --- */
        IF vIsCurrent = 1 AND vNewStart >= NOW() THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime cannot be in the future.';
        END IF;

        /* --- Guard: must not invalidate previous row --- */
        IF vPrevId IS NOT NULL AND vNewStart <= vPrevStart THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'startDateTime would invalidate previous location.';
        END IF;

        /* --- Propagate boundary to previous row --- */
        IF vPrevId IS NOT NULL AND vNewStart <> vOldStart THEN
            UPDATE plantlocationhistory
            SET endDateTime = vNewStart
            WHERE plantLocationHistoryId = vPrevId;
        END IF;

        /* --- Apply edit to target row --- */
        UPDATE plantlocationhistory
        SET
            startDateTime      = vNewStart,
            moveReasonNotes    = COALESCE(pMoveReasonNotes, moveReasonNotes),
            plantLocationNotes = COALESCE(pPlantLocationNotes, plantLocationNotes)
        WHERE plantLocationHistoryId = pPlantLocationHistoryId;

        /* --- Invariant: at most one current row --- */
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

