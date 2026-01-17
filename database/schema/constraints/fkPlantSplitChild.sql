ALTER TABLE `orchids`.`plantsplit`
  ADD CONSTRAINT `fkPlantSplitChild`
  FOREIGN KEY (`childPlantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

