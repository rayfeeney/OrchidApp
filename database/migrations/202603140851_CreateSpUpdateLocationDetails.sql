DROP PROCEDURE IF EXISTS spUpdateLocation;
DROP PROCEDURE IF EXISTS spUpdateLocationDetails;

DELIMITER //

CREATE PROCEDURE `spUpdateLocationDetails`(
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
    DECLARE vExists INT;

    IF pLocationId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'LocationId is required.';
    END IF;

    SET vName = NULLIF(TRIM(pLocationName), '');

    IF vName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location name is required.';
    END IF;

    SELECT COUNT(*) INTO vExists
    FROM location
    WHERE locationId = pLocationId;

    IF vExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Location not found.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM location
        WHERE LOWER(locationName) = LOWER(vName)
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

END;
