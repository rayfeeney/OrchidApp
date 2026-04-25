ALTER TABLE `plantsplit`
  ADD CONSTRAINT `fkPlantSplitParent`
  FOREIGN KEY (`parentPlantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

