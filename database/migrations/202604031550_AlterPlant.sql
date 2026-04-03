-- Update lifecycle boundary comments on plant table

ALTER TABLE plant
MODIFY acquisitionDate DATETIME NULL
COMMENT 'Start of the plant lifecycle in the system. All events must occur on or after this datetime. Set on creation (including split-created plants).';

ALTER TABLE plant
MODIFY endDate DATETIME NULL
COMMENT 'End of the plant lifecycle. No events may occur after this datetime. Set by terminal events (e.g. split, disposal).';
