ALTER TABLE `plantevent`
  ADD FOREIGN KEY (`observationTypeId`)
  REFERENCES `observationtype` (`Id`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

