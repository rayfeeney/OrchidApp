DELIMITER //
CREATE OR REPLACE PROCEDURE `spAddTaxon`(
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

    
    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');

    
    CALL spAddTaxonInternal(
        pGenusId,
        vSpeciesName,
        vHybridName,
        pGrowthNotes,
        pTaxonNotes,
        0,
        vNewTaxonId
    );

    
    SELECT vNewTaxonId AS TaxonId;

END
//
DELIMITER ;

