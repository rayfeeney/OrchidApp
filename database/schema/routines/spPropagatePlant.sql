SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //

CREATE OR REPLACE PROCEDURE `spPropagatePlant`(

    IN pParentPlantId INT,
    IN pPropagationDate DATE,
    IN pPropagationTypeId INT,
    IN pChildPlantName VARCHAR(100),
    IN pMediumId INT,
    IN pPropagationNotes TEXT

)
BEGIN

    DECLARE vTaxonId INT;
    DECLARE vParentPlantTag CHAR(8);
    DECLARE vParentStart DATETIME;
    DECLARE vParentEnd DATETIME;
    DECLARE vTaxonIsActive TINYINT;
    DECLARE vGenusIsActive TINYINT;

    DECLARE vChildTag CHAR(8);
    DECLARE vChildPlantId INT;

    DECLARE vPropagationDateTime DATETIME;

    IF pParentPlantId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant id is required';
    END IF;

    IF pPropagationDate IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation date is required';
    END IF;

    IF pPropagationTypeId IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation type is required';
    END IF;

    IF pPropagationDate > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation date cannot be in the future';
    END IF;

    SET vPropagationDateTime = TIMESTAMP(
        pPropagationDate,
        TIME(NOW())
    );

    START TRANSACTION;

    SELECT
        p.taxonId,
        p.plantTag,
        p.acquisitionDate,
        p.endDate,
        t.isActive,
        g.isActive
    INTO
        vTaxonId,
        vParentPlantTag,
        vParentStart,
        vParentEnd,
        vTaxonIsActive,
        vGenusIsActive
    FROM plant p
    JOIN taxon t ON p.taxonId = t.taxonId
    JOIN genus g ON t.genusId = g.genusId
    WHERE p.plantId = pParentPlantId
      AND p.isActive = 1
    FOR UPDATE;

    IF vParentEnd IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Parent plant already ended';
    END IF;

    IF vTaxonIsActive = 0 OR vGenusIsActive = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Plant must be classified under an active genus and species / hybrid';
    END IF;

    IF vPropagationDateTime < vParentStart THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Propagation datetime cannot be before plant lifecycle start';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM propagationtype
        WHERE propagationTypeId = pPropagationTypeId
          AND isActive = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid propagation type';
    END IF;

    SET vChildTag = fnGeneratePlantTag();

    INSERT INTO plant (
        taxonId,
        plantTag,
        plantName,
        acquisitionDate,
        acquisitionSource,
        isActive
    )
    VALUES (
        vTaxonId,
        vChildTag,
        pChildPlantName,
        vPropagationDateTime,
        CONCAT('Propagation from ', vParentPlantTag),
        1
    );

    SET vChildPlantId = LAST_INSERT_ID();

    IF pMediumId IS NOT NULL THEN
        INSERT INTO repotting (
            plantId,
            repotDate,
            newGrowthMediumId,
            repotReasonNotes,
            isActive
        )
        VALUES (
            vChildPlantId,
            vPropagationDateTime,
            pMediumId,
            'Initial medium from propagation',
            1
        );
    END IF;

    INSERT INTO plantpropagation (
        parentPlantId,
        childPlantId,
        propagationTypeId,
        propagationDateTime,
        propagationNotes,
        isActive
    )
    VALUES (
        pParentPlantId,
        vChildPlantId,
        pPropagationTypeId,
        vPropagationDateTime,
        pPropagationNotes,
        1
    );

    SELECT
        vChildPlantId AS childPlantId,
        vChildTag AS childPlantTag;

    COMMIT;

END
//

DELIMITER ;
