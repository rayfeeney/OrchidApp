DROP PROCEDURE IF EXISTS spAddTaxon;

DELIMITER //

CREATE PROCEDURE spAddTaxon(
    IN  pGenusId      INT,
    IN  pSpeciesName  VARCHAR(100),
    IN  pHybridName   VARCHAR(150),
    IN  pGrowthNotes  TEXT,
    IN  pTaxonNotes   TEXT
)
BEGIN
    DECLARE vSpeciesName VARCHAR(100);
    DECLARE vHybridName  VARCHAR(150);
    DECLARE vNewTaxonId  INT;

    -- UI-level normalisation only
    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');

    -- call structural primitive
    CALL spAddTaxonInternal(
        pGenusId,
        vSpeciesName,
        vHybridName,
        pGrowthNotes,
        pTaxonNotes,
        0,
        vNewTaxonId
    );

    -- UI contract: return created id
    SELECT vNewTaxonId AS TaxonId;

END //

DELIMITER ;
