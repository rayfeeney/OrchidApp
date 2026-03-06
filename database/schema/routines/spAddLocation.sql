DELIMITER //
CREATE OR REPLACE PROCEDURE `spAddLocation`(
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
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A location with this name already exists.';
    END IF;

    INSERT INTO location (
        locationName,
        locationTypeCode,
        locationNotes,
        climateCode,
        climateNotes,
        locationGeneralNotes
    )
    VALUES (
        vName,
        NULLIF(TRIM(pLocationTypeCode), ''),
        NULLIF(TRIM(pLocationNotes), ''),
        NULLIF(TRIM(pClimateCode), ''),
        NULLIF(TRIM(pClimateNotes), ''),
        NULLIF(TRIM(pLocationGeneralNotes), '')
    );

    SELECT LAST_INSERT_ID() AS locationId;

END
//
DELIMITER ;

