ALTER TABLE `repotting`
  ADD CONSTRAINT `fk_repotting_old_growthmedium`
  FOREIGN KEY (`oldGrowthMediumId`)
  REFERENCES `growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

