ALTER TABLE `taxonphoto`
  ADD CONSTRAINT `fkTaxonPhotoTaxon`
  FOREIGN KEY (`taxonId`)
  REFERENCES `taxon` (`taxonId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

