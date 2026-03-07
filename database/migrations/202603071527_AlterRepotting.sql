USE orchids;

ALTER TABLE repotting
DROP COLUMN IF EXISTS oldMediumCode;

ALTER TABLE repotting
DROP COLUMN IF EXISTS newMediumCode;