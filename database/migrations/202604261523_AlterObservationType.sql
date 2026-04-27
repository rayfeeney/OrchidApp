ALTER TABLE observationtype
  DROP INDEX ux_observationtype_typeCode;

ALTER TABLE observationtype
  ADD CONSTRAINT uxObservationType_TypeCode UNIQUE (typeCode);