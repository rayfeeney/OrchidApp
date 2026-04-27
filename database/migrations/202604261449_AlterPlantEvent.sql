-- Step 1: drop FK (wrong name)
ALTER TABLE plantevent
  DROP FOREIGN KEY fk_plantevent_observationtype;

-- Step 2: drop supporting index
ALTER TABLE plantevent
  DROP INDEX fk_plantevent_observationtype;

-- Step 3: recreate FK with correct naming + behaviour
ALTER TABLE plantevent
  ADD CONSTRAINT fkPlantEventObservationType
  FOREIGN KEY (observationTypeId)
  REFERENCES observationtype(Id)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;
