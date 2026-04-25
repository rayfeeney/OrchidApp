ALTER TABLE `plantphoto`
  ADD FOREIGN KEY (`plantEventId`)
  REFERENCES `plantevent` (`plantEventId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

