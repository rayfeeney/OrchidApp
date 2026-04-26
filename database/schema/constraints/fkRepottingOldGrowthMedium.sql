ALTER TABLE `repotting`
  ADD CONSTRAINT `fkRepottingOldGrowthMedium`
  FOREIGN KEY (`oldGrowthMediumId`)
  REFERENCES `growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

