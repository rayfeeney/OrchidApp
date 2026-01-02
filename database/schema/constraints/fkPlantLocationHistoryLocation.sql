ALTER TABLE $table
  ADD CONSTRAINT $constraintName
  FOREIGN KEY (`locationId`)
  REFERENCES $refTable (`locationId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

