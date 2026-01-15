ALTER TABLE `orchids`.`plantlocationhistory`
  ADD CONSTRAINT `fkPlantLocationHistoryPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

