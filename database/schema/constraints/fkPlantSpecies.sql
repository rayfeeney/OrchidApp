ALTER TABLE $table
  ADD CONSTRAINT $constraintName
  FOREIGN KEY (`speciesId`)
  REFERENCES $refTable (`speciesId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

