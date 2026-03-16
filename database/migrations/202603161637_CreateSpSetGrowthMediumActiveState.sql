SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS spSetGrowthMediumActiveState;

DELIMITER //

CREATE PROCEDURE spSetGrowthMediumActiveState(
    IN pGrowthMediumId INT,
    IN pIsActive BOOLEAN
)
proc: BEGIN

    DECLARE vCurrentState BOOLEAN;

    SELECT isActive
    INTO vCurrentState
    FROM growthmedium
    WHERE growthMediumId = pGrowthMediumId;

    IF vCurrentState = pIsActive THEN
        LEAVE proc;
    END IF;

    UPDATE growthmedium
    SET isActive = pIsActive
    WHERE growthMediumId = pGrowthMediumId;

END //

DELIMITER ;