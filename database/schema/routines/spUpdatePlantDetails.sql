DELIMITER //
CREATE OR REPLACE PROCEDURE `spUpdatePlantDetails`(
    IN pPlantId INT,
    IN pTaxonId INT,
    IN pPlantTag VARCHAR(50),
    IN pPlantName VARCHAR(100),
    IN pAcquisitionDate DATETIME,
    IN pAcquisitionSource VARCHAR(150),
    IN pEndDate DATETIME,
    IN pEndNotes TEXT,
    IN pPlantNotes TEXT
)
BEGIN

    DECLARE vExistingAcquisitionDate DATETIME;
    DECLARE vExistingEndDate DATETIME;
    DECLARE vIsSplitChild BOOLEAN;
    DECLARE vIsSplitParent BOOLEAN;

    
    IF pAcquisitionDate IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acquisition date is required.';
    END IF;

    
    SELECT acquisitionDate, endDate
      INTO vExistingAcquisitionDate, vExistingEndDate
      FROM plant
     WHERE plantId = pPlantId
     FOR UPDATE;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Plant not found.';
    END IF;

    
    SELECT EXISTS (
        SELECT 1 FROM plantsplitchild
        WHERE childPlantId = pPlantId
    ) INTO vIsSplitChild;

    SELECT EXISTS (
        SELECT 1 FROM plantsplit
        WHERE parentPlantId = pPlantId
    ) INTO vIsSplitParent;

    
    IF (pAcquisitionDate <=> vExistingAcquisitionDate) = 0 THEN
        IF vIsSplitChild THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot modify acquisition date: plant was created via split.';
        END IF;
    END IF;

    
    IF (pEndDate <=> vExistingEndDate) = 0 THEN
        IF vIsSplitParent THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot modify end date: plant has been split.';
        END IF;
    END IF;

    
    IF pEndDate IS NOT NULL AND pEndDate <= pAcquisitionDate THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'End date must be after acquisition date.';
    END IF;

    
    UPDATE plant
       SET taxonId = pTaxonId,
           plantTag = pPlantTag,
           plantName = pPlantName,
           acquisitionDate = pAcquisitionDate,
           acquisitionSource = pAcquisitionSource,
           endDate = pEndDate,
           endNotes = pEndNotes,
           plantNotes = pPlantNotes
     WHERE plantId = pPlantId;

END
//
DELIMITER ;

