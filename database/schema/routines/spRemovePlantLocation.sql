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
            ROLLBACK TO SAVEPOINT orchidapp_removeplantlocation;
            RELEASE SAVEPOINT orchidapp_removeplantlocation;
        END IF;
        RESIGNAL;
    END;
    IF @@in_transaction THEN
        SAVEPOINT orchidapp_removeplantlocation;
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
              AND endDateTime = vStart FOR UPDATE
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
        LIMIT 1 FOR UPDATE;
        IF vIsCurrent = 0 AND (
            SELECT COUNT(*)
            FROM plantlocationhistory
            WHERE plantId = vPlantId
              AND isActive = 1
              AND startDateTime = vEnd FOR UPDATE
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
            LIMIT 1 FOR UPDATE;
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
              AND endDateTime IS NULL FOR UPDATE
        ) > 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation after location removal.';
        END IF;
    IF vOwnTransaction THEN
        COMMIT;
    ELSE
        RELEASE SAVEPOINT orchidapp_removeplantlocation;
    END IF;
END
//

DELIMITER ;
