ALTER TABLE $table
  ADD CONSTRAINT $constraintName
  FOREIGN KEY (`childPlantId`)
  REFERENCES $refTable (`plantId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

