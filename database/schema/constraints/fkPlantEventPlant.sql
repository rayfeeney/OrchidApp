ALTER TABLE `plantevent`
  ADD CONSTRAINT `fkPlantEventPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

