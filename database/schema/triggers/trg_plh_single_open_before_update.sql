DELIMITER //
CREATE TRIGGER `trg_plh_single_open_before_update` BEFORE UPDATE ON `plantlocationhistory` FOR EACH ROW BEGIN
    -- Only care if the updated row would be an active open row
    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM orchids.plantlocationhistory
            WHERE plantId = NEW.plantId
              AND isActive = 1
              AND endDateTime IS NULL
              AND plantLocationHistoryId <> OLD.plantLocationHistoryId
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';
        END IF;
    END
//
DELIMITER ;

