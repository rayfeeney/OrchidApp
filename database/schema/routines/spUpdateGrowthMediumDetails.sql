DELIMITER //
CREATE OR REPLACE PROCEDURE `spUpdateGrowthMediumDetails`(
    IN pGrowthMediumId INT,
    IN pName VARCHAR(100),
    IN pDescription VARCHAR(500)
)
BEGIN

    DECLARE vName VARCHAR(100);

    IF pGrowthMediumId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Growth medium id is required.';
    END IF;

    SET vName = NULLIF(TRIM(pName), '');

    IF vName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Growth medium name is required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM growthmedium
        WHERE growthMediumId = pGrowthMediumId
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Growth medium not found.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM growthmedium
        WHERE name = vName
          AND growthMediumId <> pGrowthMediumId
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A growth medium with this name already exists.';
    END IF;

    UPDATE growthmedium
    SET
        name = vName,
        description = NULLIF(TRIM(pDescription), '')
    WHERE growthMediumId = pGrowthMediumId;

END
//
DELIMITER ;

