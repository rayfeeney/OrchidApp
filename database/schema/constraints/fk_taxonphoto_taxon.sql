ALTER TABLE `taxonphoto`
  ADD CONSTRAINT `fk_taxonphoto_taxon`
  FOREIGN KEY (`taxonId`)
  REFERENCES `taxon` (`taxonId`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;

