ALTER TABLE `plantevent`
  ADD CONSTRAINT `fk_plantevent_observationtype`
  FOREIGN KEY (`observationTypeId`)
  REFERENCES `observationtype` (`Id`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

