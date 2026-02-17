ALTER TABLE `orchids`.`plantsplitchild`
  ADD CONSTRAINT `fkPlantSplitChild_plant`
  FOREIGN KEY (`childPlantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

