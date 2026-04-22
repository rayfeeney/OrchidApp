ALTER TABLE `flowering`
  ADD CONSTRAINT `fkFloweringPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

