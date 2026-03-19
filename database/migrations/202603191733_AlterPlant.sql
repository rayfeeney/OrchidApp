ALTER TABLE plant DROP INDEX uqPlantPlantTag;
ALTER TABLE plant DROP COLUMN plantTag;

ALTER TABLE plant
ADD COLUMN plantTag CHAR(8) NOT NULL
COMMENT 'System-generated permanent accession identity';