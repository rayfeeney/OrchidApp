ALTER TABLE `orchids`.`plantsplit`
  ADD CONSTRAINT `fkPlantSplitParent`
  FOREIGN KEY (`parentPlantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

