DROP PROCEDURE IF EXISTS spUpdateGenus;

DELIMITER //

CREATE PROCEDURE spUpdateGenus(
    IN pGenusId INT,
    IN pGenusName VARCHAR(100),
    IN pGenusNotes TEXT
)
BEGIN
    DECLARE vName VARCHAR(100);
    DECLARE vNotes TEXT;

    DECLARE v_errno INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;

        ROLLBACK;

        IF v_errno = 1062 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Genus already exists';
        ELSE
            RESIGNAL;
        END IF;
    END;

    SET vName = NULLIF(TRIM(pGenusName), '');
    SET vNotes = NULLIF(TRIM(pGenusNotes), '');

    IF vName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus name must be provided';
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (
        SELECT 1
        FROM genus
        WHERE genusId = pGenusId
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM genus
        WHERE genusName COLLATE utf8mb4_unicode_ci =
              vName COLLATE utf8mb4_unicode_ci
          AND genusId <> pGenusId
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus already exists';
    END IF;

    UPDATE genus
    SET
        genusName = vName,
        genusNotes = vNotes
    WHERE genusId = pGenusId;

    COMMIT;

    SELECT pGenusId AS GenusId;
END //

DELIMITER ;