ALTER TABLE `plantpropagation`
  ADD CONSTRAINT `fkPlantPropagation_propagationTypeId`
  FOREIGN KEY (`propagationTypeId`)
  REFERENCES `propagationtype` (`propagationTypeId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

