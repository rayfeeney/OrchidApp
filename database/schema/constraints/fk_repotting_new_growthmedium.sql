ALTER TABLE `repotting`
  ADD FOREIGN KEY (`newGrowthMediumId`)
  REFERENCES `growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

