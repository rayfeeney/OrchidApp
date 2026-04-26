DELIMITER //
CREATE OR REPLACE PROCEDURE `spSetGrowthMediumActiveState`(
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

END
//
DELIMITER ;

