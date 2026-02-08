DELIMITER //
CREATE PROCEDURE `spAddGenus`(
    IN  pGenusName           VARCHAR(100),
    IN	pGenusNotes			 TEXT,
    OUT pGenusId             INT,
    OUT pGenusOnlyTaxonId    INT
)
BEGIN
    DECLARE vGenusName	VARCHAR(100);
    DECLARE vGenusNotes	TEXT;
    -- Single handler for all SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF MYSQL_ERRNO = 1062 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Genus already exists';
        ELSE
            ROLLBACK;
            RESIGNAL;
        END IF;
    END;

    -- Defensive initialisation (after DECLAREs)
    SET pGenusId = NULL;
    SET pGenusOnlyTaxonId = NULL;

    -- Normalise genus details
    SET vGenusName	= NULLIF(TRIM(pGenusName), '');
    SET vGenusNotes	= NULLIF(TRIM(pGenusNotes), '');

    IF vGenusName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus name must be provided';
    END IF;

    START TRANSACTION;

    -- Optional UX-friendly pre-check (still worth keeping)
    IF EXISTS (
        SELECT 1
        FROM genus
        WHERE genusName COLLATE utf8mb4_unicode_ci =
              vGenusName COLLATE utf8mb4_unicode_ci
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus already exists';
    END IF;

    INSERT INTO genus (
        genusName,
        genusNotes,
        isActive
    )
    VALUES (
        vGenusName,
        vGenusNotes,
        1
    );

    SET pGenusId = LAST_INSERT_ID();

    CALL spAddTaxonInternal(
        pGenusId,
        NULL,
        NULL,
        NULL,
        NULL,
        1,  -- isSystemManaged
        pGenusOnlyTaxonId
    );

    COMMIT;
END
//
DELIMITER ;

