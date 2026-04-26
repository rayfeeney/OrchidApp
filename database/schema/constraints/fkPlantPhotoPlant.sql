ALTER TABLE `plantphoto`
  ADD CONSTRAINT `fkPlantPhotoPlant`
  FOREIGN KEY (`plantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

