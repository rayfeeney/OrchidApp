USE orchids;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS spUpdateTaxonMetadata;
DROP PROCEDURE IF EXISTS spUpdateTaxonDetails;

DELIMITER //

CREATE PROCEDURE spUpdateTaxonDetails(
    IN p_taxonId INT,
    IN p_speciesName VARCHAR(100),
    IN p_hybridName VARCHAR(150),
    IN p_growthCode VARCHAR(30),
    IN p_growthNotes TEXT,
    IN p_taxonNotes TEXT
)
BEGIN

    DECLARE v_isSystemManaged TINYINT;

    /* Normalise empty strings to NULL */
    SET p_speciesName = NULLIF(TRIM(p_speciesName), '');
    SET p_hybridName  = NULLIF(TRIM(p_hybridName), '');

    /* Validate taxon exists and retrieve system flag */
    SELECT isSystemManaged
    INTO v_isSystemManaged
    FROM taxon
    WHERE taxonId = p_taxonId;

    IF v_isSystemManaged IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Taxon not found';
    END IF;

    /* System-managed taxa: descriptive fields only */
    IF v_isSystemManaged = 1 THEN

        UPDATE taxon
        SET
            growthCode  = p_growthCode,
            growthNotes = p_growthNotes,
            taxonNotes  = p_taxonNotes
        WHERE taxonId = p_taxonId;

    ELSE

        /* User-managed taxa: allow species or hybrid update */
        UPDATE taxon
        SET
            speciesName = p_speciesName,
            hybridName  = p_hybridName,
            growthCode  = p_growthCode,
            growthNotes = p_growthNotes,
            taxonNotes  = p_taxonNotes
        WHERE taxonId = p_taxonId;

    END IF;

END //

DELIMITER ;