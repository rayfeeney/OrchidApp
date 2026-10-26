-- C11: keep plant details and first closure of open intervals atomic.
-- Does not repair historical partially applied closures or change ended-plant UI policy.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

DELIMITER //
CREATE OR REPLACE PROCEDURE `spUpdatePlantDetails`(
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
    DECLARE vFound BOOLEAN DEFAULT TRUE;
    DECLARE vOwnTransaction BOOLEAN DEFAULT FALSE;
    DECLARE vSavepointCreated BOOLEAN DEFAULT FALSE;
    DECLARE vInvalidFlowerings INT DEFAULT 0;
    DECLARE vInvalidLocations INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET vFound = FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF vOwnTransaction THEN
            ROLLBACK;
        ELSEIF vSavepointCreated AND @@in_transaction THEN
            ROLLBACK TO SAVEPOINT orchidapp_update_plant_details;
            RELEASE SAVEPOINT orchidapp_update_plant_details;
        END IF;
        RESIGNAL;
    END;

    -- START TRANSACTION would commit a caller's active transaction: use a savepoint instead.
    IF @@in_transaction THEN
        SAVEPOINT orchidapp_update_plant_details;
        SET vSavepointCreated = TRUE;
    ELSE
        START TRANSACTION;
        SET vOwnTransaction = TRUE;
    END IF;

    SELECT acquisitionDate, endDate
      INTO vExistingAcquisitionDate, vExistingEndDate
      FROM plant
     WHERE plantId = pPlantId
     FOR UPDATE;
    IF NOT vFound THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plant not found.';
    END IF;

    SELECT EXISTS (SELECT 1 FROM plantsplitchild WHERE childPlantId = pPlantId)
      INTO vIsSplitChild;
    SELECT EXISTS (SELECT 1 FROM plantsplit WHERE parentPlantId = pPlantId)
      INTO vIsSplitParent;

    IF (DATE(pAcquisitionDate) <=> DATE(vExistingAcquisitionDate)) = 0 AND vIsSplitChild THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot modify acquisition date: plant was created via split.';
    END IF;
    IF (DATE(pEndDate) <=> DATE(vExistingEndDate)) = 0 AND vIsSplitParent THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot modify end date: plant has been split.';
    END IF;
    IF pAcquisitionDate IS NOT NULL AND DATE(pAcquisitionDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Acquisition date cannot be in the future.';
    END IF;
    IF pEndDate IS NOT NULL AND DATE(pEndDate) > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date cannot be in the future.';
    END IF;
    IF pEndDate IS NOT NULL AND pAcquisitionDate IS NOT NULL
       AND DATE(pEndDate) <= DATE(pAcquisitionDate) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date must be after acquisition date.';
    END IF;

    SET vFinalAcquisitionDate = CASE
        WHEN pAcquisitionDate IS NULL THEN NULL
        WHEN vExistingAcquisitionDate IS NULL THEN TIMESTAMP(DATE(pAcquisitionDate), CURRENT_TIME)
        ELSE TIMESTAMP(DATE(pAcquisitionDate), TIME(vExistingAcquisitionDate))
    END;
    SET vFinalEndDate = CASE
        WHEN pEndDate IS NULL THEN NULL
        WHEN vExistingEndDate IS NULL THEN TIMESTAMP(DATE(pEndDate), CURRENT_TIME)
        ELSE TIMESTAMP(DATE(pEndDate), TIME(vExistingEndDate))
    END;

    IF vExistingEndDate IS NULL AND vFinalEndDate IS NOT NULL THEN
        -- Flowering has no date-order table constraint. Lock/check open intervals explicitly.
        SELECT COUNT(*) INTO vInvalidFlowerings FROM flowering
         WHERE plantId = pPlantId AND endDate IS NULL AND startDate > vFinalEndDate
         FOR UPDATE;
        IF vInvalidFlowerings > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date cannot be before an open flowering start.';
        END IF;
        SELECT COUNT(*) INTO vInvalidLocations FROM plantlocationhistory
         WHERE plantId = pPlantId AND endDateTime IS NULL AND startDateTime >= vFinalEndDate
         FOR UPDATE;
        IF vInvalidLocations > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date must be after an open location start.';
        END IF;
    END IF;

    UPDATE plant SET taxonId = pTaxonId, plantName = pPlantName,
        acquisitionDate = vFinalAcquisitionDate, acquisitionSource = pAcquisitionSource,
        endDate = vFinalEndDate, endNotes = pEndNotes, plantNotes = pPlantNotes
     WHERE plantId = pPlantId;

    IF vExistingEndDate IS NULL AND vFinalEndDate IS NOT NULL THEN
        -- Existing location constraint enforces end strictly after its start.
        UPDATE plantlocationhistory SET endDateTime = vFinalEndDate
         WHERE plantId = pPlantId AND endDateTime IS NULL;
        UPDATE flowering SET endDate = vFinalEndDate
         WHERE plantId = pPlantId AND endDate IS NULL;
    END IF;

    IF vOwnTransaction THEN
        COMMIT;
    ELSE
        RELEASE SAVEPOINT orchidapp_update_plant_details;
    END IF;
END
//
DELIMITER ;
