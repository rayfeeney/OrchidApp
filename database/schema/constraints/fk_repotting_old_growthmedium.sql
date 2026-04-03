ALTER TABLE `orchids`.`repotting`
  ADD CONSTRAINT `fk_repotting_old_growthmedium`
  FOREIGN KEY (`oldGrowthMediumId`)
  REFERENCES `orchids`.`growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

