ALTER TABLE `repotting`
  ADD CONSTRAINT `fk_repotting_new_growthmedium`
  FOREIGN KEY (`newGrowthMediumId`)
  REFERENCES `growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

