ALTER TABLE `orchids`.`repotting`
  ADD CONSTRAINT `fk_repotting_new_growthmedium`
  FOREIGN KEY (`newGrowthMediumId`)
  REFERENCES `orchids`.`growthmedium` (`growthMediumId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

