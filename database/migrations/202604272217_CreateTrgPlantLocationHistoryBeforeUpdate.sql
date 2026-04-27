DELIMITER //

DROP TRIGGER IF EXISTS `trg_plh_single_open_before_update`//

CREATE TRIGGER `trgPlantLocationHistoryBeforeUpdate` BEFORE UPDATE ON `plantlocationhistory` FOR EACH ROW BEGIN

    
    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN

        IF EXISTS (

            SELECT 1

            FROM plantlocationhistory

            WHERE plantId = NEW.plantId

              AND isActive = 1

              AND endDateTime IS NULL

              AND plantLocationHistoryId <> OLD.plantLocationHistoryId

        ) THEN

            SIGNAL SQLSTATE '45000'

                SET MESSAGE_TEXT = 'Invariant violation: multiple open locations for plant';

        END IF;

    END IF;

END//

DELIMITER ;
