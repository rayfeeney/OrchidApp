DROP PROCEDURE IF EXISTS spUpdatePlantDetails;

DELIMITER //

CREATE PROCEDURE `spUpdatePlantDetails`(
    IN pPlantId INT,
    IN pTaxonId INT,
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

    DECLARE vFinalAcquisitionDate DATETIME;
    DECLARE vFinalEndDate DATETIME;

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
    
    IF pAcquisitionDate IS NOT NULL AND DATE(pAcquisitionDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acquisition date cannot be in the future.';
    END IF;

    
    IF pEndDate IS NOT NULL AND DATE(pEndDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'End date cannot be in the future.';
    END IF;

    
    IF pEndDate IS NOT NULL AND pAcquisitionDate IS NOT NULL
       AND DATE(pEndDate) <= DATE(pAcquisitionDate) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'End date must be after acquisition date.';
    END IF;

    SET vFinalAcquisitionDate =
        CASE
            WHEN pAcquisitionDate IS NULL THEN NULL

            
            WHEN vExistingAcquisitionDate IS NULL THEN
                TIMESTAMP(DATE(pAcquisitionDate), CURRENT_TIME)

            
            ELSE
                TIMESTAMP(DATE(pAcquisitionDate), TIME(vExistingAcquisitionDate))
        END;

    SET vFinalEndDate =
        CASE
            WHEN pEndDate IS NULL THEN NULL

            
            WHEN vExistingEndDate IS NULL THEN
                TIMESTAMP(DATE(pEndDate), CURRENT_TIME)

            
            ELSE
                TIMESTAMP(DATE(pEndDate), TIME(vExistingEndDate))
        END;

    UPDATE plant
       SET taxonId = pTaxonId,
           plantName = pPlantName,
           acquisitionDate = vFinalAcquisitionDate,
           acquisitionSource = pAcquisitionSource,
           endDate = vFinalEndDate,
           endNotes = pEndNotes,
           plantNotes = pPlantNotes
     WHERE plantId = pPlantId;

    IF vExistingEndDate IS NULL AND vFinalEndDate IS NOT NULL THEN

        
        UPDATE plantlocationhistory
           SET endDateTime = vFinalEndDate
         WHERE plantId = pPlantId
           AND endDateTime IS NULL;

        
        UPDATE flowering
           SET endDateTime = vFinalEndDate
         WHERE plantId = pPlantId
           AND endDateTime IS NULL;

    END IF;

END //

DELIMITER ;