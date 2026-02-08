DELIMITER //
CREATE PROCEDURE `spAddTaxonInternal`(
    IN  pGenusId            INT,
    IN  pSpeciesName        VARCHAR(100),
    IN  pHybridName         VARCHAR(150),
    IN  pGrowthNotes        TEXT,
    IN  pTaxonNotes         TEXT,
    IN  pIsSystemManaged    TINYINT(1),
    OUT pTaxonId            INT
)
BEGIN
    DECLARE vSpeciesName VARCHAR(100);
    DECLARE vHybridName  VARCHAR(150);
    DECLARE vGrowthNotes TEXT;
    DECLARE vTaxonNotes  TEXT;

    -- Normalise inputs
    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');
    SET vGrowthNotes = NULLIF(TRIM(pGrowthNotes), '');
    SET vTaxonNotes  = NULLIF(TRIM(pTaxonNotes), '');

    INSERT INTO taxon (
        genusId,
        speciesName,
        hybridName,
        growthNotes,
        taxonNotes,
        isSystemManaged
    )
    VALUES (
        pGenusId,
        vSpeciesName,
        vHybridName,
        vGrowthNotes,
        vTaxonNotes,
        pIsSystemManaged
    );

    SET pTaxonId = LAST_INSERT_ID();
END
//
DELIMITER ;

