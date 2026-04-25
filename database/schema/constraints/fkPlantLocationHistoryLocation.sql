ALTER TABLE `plantlocationhistory`
  ADD CONSTRAINT `fkPlantLocationHistoryLocation`
  FOREIGN KEY (`locationId`)
  REFERENCES `location` (`locationId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

