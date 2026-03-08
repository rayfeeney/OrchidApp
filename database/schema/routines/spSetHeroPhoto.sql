DELIMITER //
CREATE OR REPLACE PROCEDURE `spSetHeroPhoto`(
    IN pPlantId INT,
    IN pPlantPhotoId INT
)
BEGIN

    DECLARE vExists INT;

    
    SELECT COUNT(*)
    INTO vExists
    FROM orchids.plantphoto
    WHERE plantPhotoId = pPlantPhotoId
      AND plantId = pPlantId
      AND isActive = 1;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid hero selection';
    END IF;

    
    UPDATE orchids.plantphoto
    SET isHero = 0
    WHERE plantId = pPlantId
      AND isHero = 1
      AND isActive = 1;

    
    UPDATE orchids.plantphoto
    SET isHero = 1
    WHERE plantPhotoId = pPlantPhotoId;

END
//
DELIMITER ;

