DROP INDEX fk_plantevent_observationType ON plantevent;

CREATE INDEX idx_plantevent_observationTypeId
ON plantevent (observationTypeId);