ALTER TABLE `plantlocationhistory`
  ADD CONSTRAINT `fkPlantLocationHistoryPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

