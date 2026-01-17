ALTER TABLE `orchids`.`flowering`
  ADD CONSTRAINT `fkFloweringPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

