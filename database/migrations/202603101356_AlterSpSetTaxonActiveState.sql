USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS spSetTaxonActiveState;

DELIMITER //

CREATE PROCEDURE spSetTaxonActiveState(
    IN pTaxonId INT,
    IN pIsActive BOOLEAN
)
proc: BEGIN

    DECLARE vCurrentState BOOLEAN;
    DECLARE vIsSystemManaged BOOLEAN;

    SELECT isActive, isSystemManaged
    INTO vCurrentState, vIsSystemManaged
    FROM taxon
    WHERE taxonId = pTaxonId;

    IF vIsSystemManaged = 1 AND pIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'System-managed records cannot be deactivated';
    END IF;

    IF vCurrentState = pIsActive THEN
        LEAVE proc;
    END IF;

    UPDATE taxon
    SET isActive = pIsActive
    WHERE taxonId = pTaxonId;

END; //