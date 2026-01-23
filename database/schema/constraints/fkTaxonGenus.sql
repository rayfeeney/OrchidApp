ALTER TABLE `orchids`.`taxon`
  ADD CONSTRAINT `fkTaxonGenus`
  FOREIGN KEY (`genusId`)
  REFERENCES `orchids`.`genus` (`genusId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

