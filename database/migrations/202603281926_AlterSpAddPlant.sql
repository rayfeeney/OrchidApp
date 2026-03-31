DROP PROCEDURE IF EXISTS spAddPlant;

DELIMITER //

CREATE  PROCEDURE `spAddPlant`(
    IN pTaxonId INT,
    IN pAcquisitionDate DATETIME,
    IN pAcquisitionSource VARCHAR(150),
    IN pPlantName VARCHAR(100),
    IN pPlantNotes TEXT
)
BEGIN
    DECLARE vTaxonIsActive TINYINT;
    DECLARE vGenusIsActive TINYINT;
    DECLARE vPlantTag CHAR(8);
    DECLARE vPlantId INT;

    IF pTaxonId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'TaxonId is required';
    END IF;

    SELECT
        t.isActive,
        g.isActive
    INTO
        vTaxonIsActive,
        vGenusIsActive
    FROM taxon t
    JOIN genus g ON t.genusId = g.genusId
    WHERE t.taxonId = pTaxonId;

    IF vTaxonIsActive IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Taxon not found';
    END IF;

    IF vTaxonIsActive = 0 OR vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant must be classified under an active genus and species / hybrid';
    END IF;

    IF pAcquisitionDate IS NOT NULL AND DATE(pAcquisitionDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Acquisition date cannot be in the future.';
    END IF;

    SET vPlantTag = fnGeneratePlantTag();

    SET pPlantName = NULLIF(TRIM(pPlantName), '');
    SET pAcquisitionSource = NULLIF(TRIM(pAcquisitionSource), '');
    SET pPlantNotes = NULLIF(TRIM(pPlantNotes), '');

    INSERT INTO plant (
        taxonId,
        plantTag,
        plantName,
        acquisitionDate,
        acquisitionSource,
        plantNotes,
        isActive,
        endDate,
        endReasonCode,
        endNotes
    )
    VALUES (
        pTaxonId,
        vPlantTag,
        pPlantName,
        CASE
            WHEN pAcquisitionDate IS NULL THEN NULL
            ELSE TIMESTAMP(DATE(pAcquisitionDate), TIME(NOW()))
        END,
        pAcquisitionSource,
        pPlantNotes,
        1,
        NULL,
        NULL,
        NULL
    );

    SET vPlantId = LAST_INSERT_ID();

    SELECT
        vPlantId AS plantId,
        vPlantTag AS plantTag;

END //

DELIMITER ;