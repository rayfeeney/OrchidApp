DELIMITER //

DROP TRIGGER IF EXISTS `trgPlantLocationHistoryBeforeInsert`//

CREATE TRIGGER `trgPlantLocationHistoryBeforeInsert` BEFORE INSERT ON `plantlocationhistory` FOR EACH ROW BEGIN

    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN

        IF EXISTS (

            SELECT 1

            FROM plantlocationhistory

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
