DELIMITER //

DROP TRIGGER IF EXISTS `trg_plh_single_open_before_insert`//

CREATE TRIGGER `trg_plh_single_open_before_insert` BEFORE INSERT ON `plantlocationhistory` FOR EACH ROW BEGIN
    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM orchids.plantlocationhistory
            WHERE plantId = NEW.plantId
              AND isActive = 1
              AND endDateTime IS NULL
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';
        END IF;
    END IF;
END//

DELIMITER ;
