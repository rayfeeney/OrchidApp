ALTER TABLE `plantsplit`
  ADD FOREIGN KEY (`parentPlantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

