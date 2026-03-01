ALTER TABLE `orchids`.`plantphoto`
  ADD CONSTRAINT `fk_plantphoto_plant`
  FOREIGN KEY (`plantId`)
  REFERENCES `orchids`.`plant` (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

