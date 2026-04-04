ALTER TABLE `orchids`.`taxonphoto`
  ADD CONSTRAINT `fk_taxonphoto_taxon`
  FOREIGN KEY (`taxonId`)
  REFERENCES `orchids`.`taxon` (`taxonId`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;

