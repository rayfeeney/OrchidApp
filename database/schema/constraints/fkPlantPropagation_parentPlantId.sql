ALTER TABLE `plantpropagation`
  ADD CONSTRAINT `fkPlantPropagation_parentPlantId`
  FOREIGN KEY (`parentPlantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

