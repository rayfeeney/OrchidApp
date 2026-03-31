DROP PROCEDURE IF EXISTS spUpdatePlantDetails;

DELIMITER //

CREATE PROCEDURE `spUpdatePlantDetails`(
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

    DECLARE vFinalAcquisitionDate DATETIME;
    DECLARE vFinalEndDate DATETIME;

    -- =========================================
    -- Load existing row (lock for consistency)
    -- =========================================

    SELECT acquisitionDate, endDate
      INTO vExistingAcquisitionDate, vExistingEndDate
      FROM plant
     WHERE plantId = pPlantId
     FOR UPDATE;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Plant not found.';
    END IF;

    -- =========================================
    -- Split protections
    -- =========================================

    SELECT EXISTS (
        SELECT 1 FROM plantsplitchild
        WHERE childPlantId = pPlantId
    ) INTO vIsSplitChild;

    SELECT EXISTS (
        SELECT 1 FROM plantsplit
        WHERE parentPlantId = pPlantId
    ) INTO vIsSplitParent;

    -- Prevent acquisition change for split child
    IF (pAcquisitionDate <=> vExistingAcquisitionDate) = 0 THEN
        IF vIsSplitChild THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot modify acquisition date: plant was created via split.';
        END IF;
    END IF;

    -- Prevent end date change for split parent
    IF (pEndDate <=> vExistingEndDate) = 0 THEN
        IF vIsSplitParent THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot modify end date: plant has been split.';
        END IF;
    END IF;

    -- =========================================
    -- Date validation (DATE-based)
    -- =========================================

    -- Acquisition cannot be in the future
    IF pAcquisitionDate IS NOT NULL AND DATE(pAcquisitionDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acquisition date cannot be in the future.';
    END IF;

    -- End date cannot be in the future
    IF pEndDate IS NOT NULL AND DATE(pEndDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'End date cannot be in the future.';
    END IF;

    -- End must be after acquisition (no same-day allowed)
    IF pEndDate IS NOT NULL AND pAcquisitionDate IS NOT NULL
       AND DATE(pEndDate) <= DATE(pAcquisitionDate) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'End date must be after acquisition date.';
    END IF;

    -- =========================================
    -- Compute FINAL AcquisitionDate
    -- =========================================

    SET vFinalAcquisitionDate =
        CASE
            WHEN pAcquisitionDate IS NULL THEN NULL

            -- First time set → assign current time
            WHEN vExistingAcquisitionDate IS NULL THEN
                TIMESTAMP(DATE(pAcquisitionDate), CURRENT_TIME)

            -- Existing value → preserve time
            ELSE
                TIMESTAMP(DATE(pAcquisitionDate), TIME(vExistingAcquisitionDate))
        END;

    -- =========================================
    -- Compute FINAL EndDate
    -- =========================================

    SET vFinalEndDate =
        CASE
            WHEN pEndDate IS NULL THEN NULL

            -- First time set → assign current time
            WHEN vExistingEndDate IS NULL THEN
                TIMESTAMP(DATE(pEndDate), CURRENT_TIME)

            -- Existing value → preserve time
            ELSE
                TIMESTAMP(DATE(pEndDate), TIME(vExistingEndDate))
        END;

    -- =========================================
    -- Update plant
    -- =========================================

    UPDATE plant
       SET taxonId = pTaxonId,
           plantTag = pPlantTag,
           plantName = pPlantName,
           acquisitionDate = vFinalAcquisitionDate,
           acquisitionSource = pAcquisitionSource,
           endDate = vFinalEndDate,
           endNotes = pEndNotes,
           plantNotes = pPlantNotes
     WHERE plantId = pPlantId;

    -- =========================================
    -- Lifecycle cascade (NO TRIGGERS)
    -- Only when plant is ended for first time
    -- =========================================

    IF vExistingEndDate IS NULL AND vFinalEndDate IS NOT NULL THEN

        -- Close open location history
        UPDATE plantlocationhistory
           SET endDateTime = vFinalEndDate
         WHERE plantId = pPlantId
           AND endDateTime IS NULL;

        -- Close open flowering records
        UPDATE flowering
           SET endDateTime = vFinalEndDate
         WHERE plantId = pPlantId
           AND endDateTime IS NULL;

    END IF;

END //

DELIMITER ;