ALTER TABLE `repotting`
  ADD CONSTRAINT `fkRepottingNewGrowthMedium`
  FOREIGN KEY (`newGrowthMediumId`)
  REFERENCES `growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

