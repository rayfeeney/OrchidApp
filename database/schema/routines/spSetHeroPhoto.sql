SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spSetHeroPhoto`(
    IN pPlantId INT,
    IN pPlantPhotoId INT
)
BEGIN

    DECLARE vExists INT;
    DECLARE vLockedPlantId INT;
    DECLARE vLockedEnd DATETIME;
    DECLARE vOwnTransaction BOOLEAN DEFAULT FALSE;
    DECLARE vSavepointCreated BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF vOwnTransaction THEN
            ROLLBACK;
        ELSEIF vSavepointCreated AND @@in_transaction THEN
            ROLLBACK TO SAVEPOINT orchidapp_setherophoto;
            RELEASE SAVEPOINT orchidapp_setherophoto;
        END IF;
        RESIGNAL;
    END;
    IF @@in_transaction THEN
        SAVEPOINT orchidapp_setherophoto;
        SET vSavepointCreated = TRUE;
    ELSE
        START TRANSACTION;
        SET vOwnTransaction = TRUE;
    END IF;
    SELECT plantId,endDate INTO vLockedPlantId,vLockedEnd
      FROM plant WHERE plantId=pPlantId AND isActive=1 FOR UPDATE;
    IF vLockedPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Active plant not found.';
    END IF;
    IF vLockedEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ended plants are read-only.';
    END IF;

    SELECT COUNT(*)
    INTO vExists
    FROM plantphoto
    WHERE plantPhotoId = pPlantPhotoId
      AND plantId = pPlantId
      AND isActive = 1 FOR UPDATE;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid hero selection';
    END IF;

    UPDATE plantphoto
    SET isHero = 0
    WHERE plantId = pPlantId
      AND isHero = 1
      AND isActive = 1;

    UPDATE plantphoto
    SET isHero = 1
    WHERE plantPhotoId = pPlantPhotoId;

    IF vOwnTransaction THEN
        COMMIT;
    ELSE
        RELEASE SAVEPOINT orchidapp_setherophoto;
    END IF;
END
//

DELIMITER ;
