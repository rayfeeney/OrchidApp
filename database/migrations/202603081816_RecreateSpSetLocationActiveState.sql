USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS spSetLocationActiveState;

DELIMITER //

CREATE PROCEDURE `spSetLocationActiveState`(
    IN pLocationId INT,
    IN pIsActive TINYINT
)
BEGIN

    IF pIsActive NOT IN (0,1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid value provided.';
    END IF;

    UPDATE location
    SET isActive = pIsActive
    WHERE locationId = pLocationId
    AND IsActive != pIsActive;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location not found.';
    END IF;

END //