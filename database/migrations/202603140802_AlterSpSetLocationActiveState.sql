DROP PROCEDURE IF EXISTS spSetLocationActiveState;

DELIMITER //

CREATE PROCEDURE `spSetLocationActiveState`(
    IN pLocationId INT,
    IN pIsActive TINYINT
)
BEGIN

    DECLARE vCurrentState TINYINT;

    IF pLocationId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'LocationId is required.';
    END IF;

    IF pIsActive NOT IN (0,1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid value provided.';
    END IF;

    SELECT isActive
    INTO vCurrentState
    FROM location
    WHERE locationId = pLocationId;

    IF vCurrentState IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location not found.';
    END IF;

    IF vCurrentState = pIsActive THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No change required.';
    END IF;

    UPDATE location
    SET isActive = pIsActive
    WHERE locationId = pLocationId;

END //

DELIMITER ;
