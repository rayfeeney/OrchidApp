-- 1. Drop FK
ALTER TABLE plantevent
DROP FOREIGN KEY fk_plantevent_observationtype;

-- 2. Drop index
DROP INDEX idx_plantevent_observationTypeId ON plantevent;

-- 3. Recreate FK (let MariaDB create index automatically)
ALTER TABLE plantevent
ADD CONSTRAINT fk_plantevent_observationtype
FOREIGN KEY (observationTypeId)
REFERENCES observationtype (Id)
ON DELETE RESTRICT
ON UPDATE RESTRICT;