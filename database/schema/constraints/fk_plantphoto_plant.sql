ALTER TABLE `plantphoto`
  ADD CONSTRAINT `fk_plantphoto_plant`
  FOREIGN KEY (`plantId`)
  REFERENCES `plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

