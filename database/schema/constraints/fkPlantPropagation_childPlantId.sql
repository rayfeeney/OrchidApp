ALTER TABLE `plantpropagation`
  ADD CONSTRAINT `fkPlantPropagation_childPlantId`
  FOREIGN KEY (`childPlantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

