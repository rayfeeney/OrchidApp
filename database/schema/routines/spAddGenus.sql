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
    
    DECLARE v_errno INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;

        IF v_errno = 1062 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Genus already exists';
        ELSE
            ROLLBACK;
            RESIGNAL;
        END IF;
    END;

    
    SET pGenusId = NULL;
    SET pGenusOnlyTaxonId = NULL;

    
    SET vGenusName	= NULLIF(TRIM(pGenusName), '');
    SET vGenusNotes	= NULLIF(TRIM(pGenusNotes), '');

    IF vGenusName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus name must be provided';
    END IF;

    START TRANSACTION;

    
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
        1,  
        pGenusOnlyTaxonId
    );

    COMMIT;
END
//
DELIMITER ;

