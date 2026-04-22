ALTER TABLE `repotting`
  ADD CONSTRAINT `fkRepottingPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

