ALTER TABLE `repotting`
  ADD FOREIGN KEY (`oldGrowthMediumId`)
  REFERENCES `growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

