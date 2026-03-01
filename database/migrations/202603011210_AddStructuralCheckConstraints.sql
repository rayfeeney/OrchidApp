/* 
    Structural hardening migration
    Adds missing CHECK constraints for boolean fields
    Adds temporal integrity check for plantlocationhistory
*/

USE orchids;

-- 1️ plantphoto – enforce boolean isHero

ALTER TABLE plantphoto
    ADD CONSTRAINT chkPlantPhotoIsHero
    CHECK (isHero IN (0,1));


-- 2️ plantsplit – enforce boolean isActive

ALTER TABLE plantsplit
    ADD CONSTRAINT chkPlantSplitIsActive
    CHECK (isActive IN (0,1));


-- 3️ plantsplitchild – enforce boolean isActive

ALTER TABLE plantsplitchild
    ADD CONSTRAINT chkPlantSplitChildIsActive
    CHECK (isActive IN (0,1));


-- 4️ plantlocationhistory – enforce temporal integrity

ALTER TABLE plantlocationhistory
    ADD CONSTRAINT chkPlantLocationHistoryDateOrder
    CHECK (
        endDateTime IS NULL
        OR endDateTime > startDateTime
    );