DELIMITER //
CREATE OR REPLACE PROCEDURE `spAddTaxonInternal`(
    IN  pGenusId            INT,
    IN  pSpeciesName        VARCHAR(100),
    IN  pHybridName         VARCHAR(150),
    IN  pGrowthNotes        TEXT,
    IN  pTaxonNotes         TEXT,
    IN  pIsSystemManaged    TINYINT(1),
    OUT pTaxonId            INT
)
BEGIN
    DECLARE vGenusIsActive TINYINT;

    DECLARE vSpeciesName VARCHAR(100);
    DECLARE vHybridName  VARCHAR(150);
    DECLARE vGrowthNotes TEXT;
    DECLARE vTaxonNotes  TEXT;

    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');
    SET vGrowthNotes = NULLIF(TRIM(pGrowthNotes), '');
    SET vTaxonNotes  = NULLIF(TRIM(pTaxonNotes), '');

    SELECT isActive
    INTO vGenusIsActive
    FROM genus
    WHERE genusId = pGenusId;

    IF vGenusIsActive IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid genusId: genus does not exist';
    END IF;

    IF vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Taxon must be created under an active genus.';
    END IF;

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

