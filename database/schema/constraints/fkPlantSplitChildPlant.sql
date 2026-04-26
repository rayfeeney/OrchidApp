ALTER TABLE `plantsplitchild`
  ADD CONSTRAINT `fkPlantSplitChildPlant`
  FOREIGN KEY (`childPlantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

