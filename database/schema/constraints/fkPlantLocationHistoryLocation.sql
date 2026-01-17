ALTER TABLE `orchids`.`plantlocationhistory`
  ADD CONSTRAINT `fkPlantLocationHistoryLocation`
  FOREIGN KEY (`locationId`)
  REFERENCES `orchids`.`location` (`locationId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

