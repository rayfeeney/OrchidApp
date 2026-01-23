ALTER TABLE `orchids`.`plant`
  ADD CONSTRAINT `fkPlantTaxon`
  FOREIGN KEY (`taxonId`)
  REFERENCES `orchids`.`taxon` (`taxonId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

