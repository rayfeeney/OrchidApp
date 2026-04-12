-- Delete DQ issue record with null newGrowthMediumId
DELETE FROM repotting
WHERE newGrowthMediumId IS NULL;

-- Alter newGrowthMediumId to be NOT NULL
ALTER TABLE repotting
MODIFY newGrowthMediumId INT NOT NULL;