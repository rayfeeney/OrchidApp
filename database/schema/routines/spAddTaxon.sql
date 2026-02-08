DELIMITER //
CREATE PROCEDURE `spAddTaxon`(
    IN  pGenusId      INT,
    IN  pSpeciesName  VARCHAR(100),
    IN  pHybridName   VARCHAR(150),
    IN  pGrowthNotes  TEXT,
    IN  pTaxonNotes   TEXT
)
BEGIN
    DECLARE vGenusExists INT;
    DECLARE vGenusIsActive INT;

    DECLARE vSpeciesName VARCHAR(100);
    DECLARE vHybridName  VARCHAR(150);

    -- Normalise for validation
    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');

    -- Validate genus
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
            SET MESSAGE_TEXT = 'Cannot create species/hybrid for inactive genus';
    END IF;

    -- Enforce shape
    IF vSpeciesName IS NULL AND vHybridName IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus-only record creation is not allowed';
    END IF;

    IF vSpeciesName IS NOT NULL AND vHybridName IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Must be either species or hybrid, not both';
    END IF;

    -- Delegate insert
    CALL spAddTaxonInternal(
        pGenusId,
        pSpeciesName,
        pHybridName,
        pGrowthNotes,
        pTaxonNotes,
        0,          -- isSystemManaged
        @ignoredTaxonId
    );
END
//
DELIMITER ;

