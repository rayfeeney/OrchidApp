USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS spUpdateLocation;

DELIMITER //

CREATE PROCEDURE `spUpdateLocation`(
    IN pLocationId INT,
    IN pLocationName VARCHAR(100),
    IN pLocationTypeCode VARCHAR(30),
    IN pLocationNotes TEXT,
    IN pClimateCode VARCHAR(30),
    IN pClimateNotes TEXT,
    IN pLocationGeneralNotes TEXT
)
BEGIN

    DECLARE vName VARCHAR(100);

    SET vName = NULLIF(TRIM(pLocationName), '');

    IF vName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location name is required.';
    END IF;

    
    IF EXISTS (
        SELECT 1
        FROM location
        WHERE locationName = vName
        AND locationId <> pLocationId
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A location with this name already exists.';
    END IF;

    UPDATE location
    SET
        locationName = vName,
        locationTypeCode = NULLIF(TRIM(pLocationTypeCode), ''),
        locationNotes = NULLIF(TRIM(pLocationNotes), ''),
        climateCode = NULLIF(TRIM(pClimateCode), ''),
        climateNotes = NULLIF(TRIM(pClimateNotes), ''),
        locationGeneralNotes = NULLIF(TRIM(pLocationGeneralNotes), '')
    WHERE locationId = pLocationId;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location not found.';
    END IF;

END //