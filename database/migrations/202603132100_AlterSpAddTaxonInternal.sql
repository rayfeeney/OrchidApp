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
    DECLARE vSpeciesName VARCHAR(100);
    DECLARE vHybridName  VARCHAR(150);
    DECLARE vGrowthNotes TEXT;
    DECLARE vTaxonNotes  TEXT;
    DECLARE vGenusExists INT;
    DECLARE vGenusIsActive INT;
    DECLARE v_errno INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO;

        IF v_errno = 1062 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Taxon already exists for this genus';
        ELSE
            RESIGNAL;
        END IF;
    END;

    SET vSpeciesName = NULLIF(TRIM(pSpeciesName), '');
    SET vHybridName  = NULLIF(TRIM(pHybridName), '');
    SET vGrowthNotes = NULLIF(TRIM(pGrowthNotes), '');
    SET vTaxonNotes  = NULLIF(TRIM(pTaxonNotes), '');

    SELECT COUNT(*), MAX(isActive)
    INTO vGenusExists, vGenusIsActive
    FROM genus
    WHERE genusId = pGenusId;

    IF vGenusExists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Genus does not exist';
    END IF;

    IF pIsSystemManaged = 0 AND vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot create taxon for inactive genus';
    END IF;

    IF pIsSystemManaged = 0 THEN
        IF vSpeciesName IS NULL AND vHybridName IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Species or hybrid must be provided';
        END IF;

        IF vSpeciesName IS NOT NULL AND vHybridName IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Must be either species or hybrid';
        END IF;
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
