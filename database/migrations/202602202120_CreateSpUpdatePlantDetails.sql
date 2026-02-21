DROP PROCEDURE IF EXISTS spUpdatePlantDetails;
DELIMITER //

CREATE PROCEDURE spUpdatePlantDetails (
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

    -- acquisitionDate must not be NULL
    IF pAcquisitionDate IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acquisition date is required.';
    END IF;

    -- Lock plant row
    SELECT acquisitionDate, endDate
      INTO vExistingAcquisitionDate, vExistingEndDate
      FROM plant
     WHERE plantId = pPlantId
     FOR UPDATE;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Plant not found.';
    END IF;

    -- Detect split relationships
    SELECT EXISTS (
        SELECT 1 FROM plantsplitchild
        WHERE childPlantId = pPlantId
    ) INTO vIsSplitChild;

    SELECT EXISTS (
        SELECT 1 FROM plantsplit
        WHERE parentPlantId = pPlantId
    ) INTO vIsSplitParent;

    -- Prevent acquisitionDate change if split child
    IF (pAcquisitionDate <=> vExistingAcquisitionDate) = 0 THEN
        IF vIsSplitChild THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot modify acquisition date: plant was created via split.';
        END IF;
    END IF;

    -- Prevent endDate change if split parent
    IF (pEndDate <=> vExistingEndDate) = 0 THEN
        IF vIsSplitParent THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot modify end date: plant has been split.';
        END IF;
    END IF;

    -- Logical validation
    IF pEndDate IS NOT NULL AND pEndDate <= pAcquisitionDate THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'End date must be after acquisition date.';
    END IF;

    -- Update (does NOT modify isActive)
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

END //

DELIMITER ;