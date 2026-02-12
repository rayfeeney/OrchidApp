ALTER TABLE `orchids`.`plantphoto`
  ADD CONSTRAINT `fk_plantphoto_plantevent`
  FOREIGN KEY (`plantEventId`)
  REFERENCES `orchids`.`plantevent` (`plantEventId`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;

