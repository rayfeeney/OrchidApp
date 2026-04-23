-- add a harmless comment
-- test change
-- 1. Drop FK (must be first)
ALTER TABLE plantevent
DROP FOREIGN KEY fk_plantevent_observationtype;

-- 2. Drop incorrect index
DROP INDEX fk_plantevent_observationType ON plantevent;

-- 3. Create correct index
CREATE INDEX idx_plantevent_observationTypeId
ON plantevent (observationTypeId);

-- 4. Recreate FK
ALTER TABLE plantevent
ADD CONSTRAINT fk_plantevent_observationtype
FOREIGN KEY (observationTypeId)
REFERENCES observationtype (Id)
ON DELETE RESTRICT
ON UPDATE RESTRICT;