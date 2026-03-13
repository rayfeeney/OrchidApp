DELIMITER //
CREATE OR REPLACE PROCEDURE `spUpdateTaxonDetails`(
    IN p_taxonId INT,
    IN p_speciesName VARCHAR(100),
    IN p_hybridName VARCHAR(150),
    IN p_growthCode VARCHAR(30),
    IN p_growthNotes TEXT,
    IN p_taxonNotes TEXT
)
BEGIN

    DECLARE v_isSystemManaged TINYINT;
    DECLARE v_existingSpecies VARCHAR(100);
    DECLARE v_existingHybrid VARCHAR(150);

    SET p_speciesName = NULLIF(TRIM(p_speciesName), '');
    SET p_hybridName  = NULLIF(TRIM(p_hybridName), '');

    SELECT isSystemManaged, speciesName, hybridName
    INTO v_isSystemManaged, v_existingSpecies, v_existingHybrid
    FROM taxon
    WHERE taxonId = p_taxonId;

    IF v_isSystemManaged IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Taxon not found';
    END IF;

    START TRANSACTION;

    IF v_isSystemManaged = 1 THEN

        UPDATE taxon
        SET
            growthCode  = p_growthCode,
            growthNotes = p_growthNotes,
            taxonNotes  = p_taxonNotes
        WHERE taxonId = p_taxonId;

    ELSE

        

        IF v_existingSpecies IS NOT NULL AND p_hybridName IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Species taxon cannot be converted to hybrid';
        END IF;

        IF v_existingHybrid IS NOT NULL AND p_speciesName IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hybrid taxon cannot be converted to species';
        END IF;

        IF p_speciesName IS NULL AND p_hybridName IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Taxon must have either species or hybrid name';
        END IF;

        IF p_speciesName IS NOT NULL AND p_hybridName IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Taxon cannot have both species and hybrid names';
        END IF;

        

        IF p_speciesName IS NOT NULL AND EXISTS (
            SELECT 1
            FROM taxon
            WHERE speciesName = p_speciesName
              AND taxonId <> p_taxonId
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Species already exists';
        END IF;

        IF p_hybridName IS NOT NULL AND EXISTS (
            SELECT 1
            FROM taxon
            WHERE hybridName = p_hybridName
              AND taxonId <> p_taxonId
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hybrid already exists';
        END IF;

        UPDATE taxon
        SET
            speciesName = p_speciesName,
            hybridName  = p_hybridName,
            growthCode  = p_growthCode,
            growthNotes = p_growthNotes,
            taxonNotes  = p_taxonNotes
        WHERE taxonId = p_taxonId;

    END IF;

    COMMIT;

END
//
DELIMITER ;

