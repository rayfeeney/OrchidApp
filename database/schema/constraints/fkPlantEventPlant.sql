ALTER TABLE `orchids`.`plantevent`
  ADD CONSTRAINT `fkPlantEventPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

