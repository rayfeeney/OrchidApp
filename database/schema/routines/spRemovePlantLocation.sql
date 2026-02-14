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

        /* ---------- Load target (locked) ---------- */

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

        /* ---------- Guard: previous ambiguity ---------- */

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

        /* ---------- Guard: next ambiguity ---------- */

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

        /* ---------- Re-stitch ---------- */

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

        /* ---------- Post-invariant ---------- */

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

