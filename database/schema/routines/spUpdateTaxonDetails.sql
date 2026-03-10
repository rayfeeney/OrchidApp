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

    
    SET p_speciesName = NULLIF(TRIM(p_speciesName), '');
    SET p_hybridName  = NULLIF(TRIM(p_hybridName), '');

    
    SELECT isSystemManaged
    INTO v_isSystemManaged
    FROM taxon
    WHERE taxonId = p_taxonId;

    IF v_isSystemManaged IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Taxon not found';
    END IF;

    
    IF v_isSystemManaged = 1 THEN

        UPDATE taxon
        SET
            growthCode  = p_growthCode,
            growthNotes = p_growthNotes,
            taxonNotes  = p_taxonNotes
        WHERE taxonId = p_taxonId;

    ELSE

        
        UPDATE taxon
        SET
            speciesName = p_speciesName,
            hybridName  = p_hybridName,
            growthCode  = p_growthCode,
            growthNotes = p_growthNotes,
            taxonNotes  = p_taxonNotes
        WHERE taxonId = p_taxonId;

    END IF;

END
//
DELIMITER ;

