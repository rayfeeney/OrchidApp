ALTER TABLE `plantphoto`
  ADD CONSTRAINT `fkPlantPhotoPlantEvent`
  FOREIGN KEY (`plantEventId`)
  REFERENCES `plantevent` (`plantEventId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

