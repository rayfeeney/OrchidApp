USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS spAddGrowthMedium;

DELIMITER //

CREATE PROCEDURE spAddGrowthMedium(
    IN pName VARCHAR(100),
    IN pDescription VARCHAR(500)
)
BEGIN

    DECLARE vName VARCHAR(100);

    SET vName = NULLIF(TRIM(pName), '');

    IF vName IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Growth medium name is required.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM growthmedium
        WHERE name = vName
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A growth medium with this name already exists.';
    END IF;

    INSERT INTO growthmedium (
        name,
        description
    )
    VALUES (
        vName,
        NULLIF(TRIM(pDescription), '')
    );

    SELECT LAST_INSERT_ID() AS growthMediumId;

END //  

DELIMITER ;