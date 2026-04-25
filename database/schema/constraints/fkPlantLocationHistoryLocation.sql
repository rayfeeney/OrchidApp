ALTER TABLE `plantlocationhistory`
  ADD FOREIGN KEY (`locationId`)
  REFERENCES `location` (`locationId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

