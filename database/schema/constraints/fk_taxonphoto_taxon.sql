ALTER TABLE `taxonphoto`
  ADD FOREIGN KEY (`taxonId`)
  REFERENCES `taxon` (`taxonId`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;

