DROP PROCEDURE IF EXISTS spSetGenusActiveState;

DELIMITER //

CREATE PROCEDURE `spSetGenusActiveState`(
    IN pGenusId INT,
    IN pIsActive TINYINT
)
BEGIN

    DECLARE vCurrentState TINYINT;
    DECLARE vExists INT;

    IF pGenusId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GenusId is required.';
    END IF;

    IF pIsActive NOT IN (0,1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid value provided.';
    END IF;

    SELECT COUNT(*) INTO vExists
    FROM genus
    WHERE genusId = pGenusId;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus not found.';
    END IF;

    SELECT isActive
    INTO vCurrentState
    FROM genus
    WHERE genusId = pGenusId;

    IF vCurrentState = pIsActive THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No change required.';
    END IF;

    UPDATE genus
    SET isActive = pIsActive
    WHERE genusId = pGenusId;

END //

DELIMITER ;
