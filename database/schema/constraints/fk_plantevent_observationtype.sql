ALTER TABLE `orchids`.`plantevent`
  ADD CONSTRAINT `fk_plantevent_observationtype`
  FOREIGN KEY (`observationTypeId`)
  REFERENCES `orchids`.`observationtype` (`Id`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

