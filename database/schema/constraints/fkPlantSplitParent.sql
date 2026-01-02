ALTER TABLE $table
  ADD CONSTRAINT $constraintName
  FOREIGN KEY (`parentPlantId`)
  REFERENCES $refTable (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

