ALTER TABLE `plantphoto`
  ADD CONSTRAINT `fk_plantphoto_plantevent`
  FOREIGN KEY (`plantEventId`)
  REFERENCES `plantevent` (`plantEventId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

