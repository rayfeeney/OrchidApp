ALTER TABLE `plantevent`
  ADD CONSTRAINT `fkPlantEventObservationType`
  FOREIGN KEY (`observationTypeId`)
  REFERENCES `observationtype` (`Id`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

