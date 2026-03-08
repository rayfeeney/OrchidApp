USE orchids;

ALTER TABLE `orchids`.`repotting`
ADD COLUMN `oldGrowthMediumId` INT NULL COMMENT 'Foreign key to growthmedium.growthMediumId representing the old growth medium used before repotting';

ALTER TABLE `orchids`.`repotting`
ADD COLUMN `newGrowthMediumId` INT NULL COMMENT 'Foreign key to growthmedium.growthMediumId representing the new growth medium used after repotting';