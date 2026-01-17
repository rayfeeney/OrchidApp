ALTER TABLE `orchids`.`plant`
  ADD CONSTRAINT `fkPlantSpecies`
  FOREIGN KEY (`speciesId`)
  REFERENCES `orchids`.`species` (`speciesId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

