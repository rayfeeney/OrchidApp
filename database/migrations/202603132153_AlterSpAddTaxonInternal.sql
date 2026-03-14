DROP PROCEDURE IF EXISTS spAddTaxonInternal;

DELIMITER //

CREATE PROCEDURE spAddTaxonInternal(
    IN  pGenusId            INT,
    IN  pSpeciesName        VARCHAR(100),
    IN  pHybridName         VARCHAR(150),
    IN  pGrowthNotes        TEXT,
    IN  pTaxonNotes         TEXT,
    IN  pIsSystemManaged    TINYINT(1),
    OUT pTaxonId            INT
)
BEGIN
    DECLARE vGenusExists INT;
    DECLARE vGenusIsActive INT;

    DECLARE vSpeciesName VARCHAR(100);
    DECLARE vHybridName  VARCHAR(150);
    DECLARE vGrowthNotes TEXT;
    DECLARE vTaxonNotes  TEXT;

    -- Normalisation
    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');
    SET vGrowthNotes = NULLIF(TRIM(pGrowthNotes), '');
    SET vTaxonNotes  = NULLIF(TRIM(pTaxonNotes), '');

    -- Structural genus validation
    SELECT COUNT(*), MAX(isActive)
    INTO vGenusExists, vGenusIsActive
    FROM genus
    WHERE genusId = pGenusId;

    IF vGenusExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid genusId: genus does not exist';
    END IF;

    IF vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot create taxon for inactive genus';
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

END //

DELIMITER ;
