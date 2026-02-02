ALTER TABLE `orchids`.`repotting`
  ADD CONSTRAINT `fkRepottingPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

