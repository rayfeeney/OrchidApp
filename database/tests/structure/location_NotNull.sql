-- location_NotNull.sql
START TRANSACTION;

-- locationName must not be NULL (must fail)
INSERT INTO orchids.location (locationName, isActive)
VALUES (NULL, 1);

ROLLBACK;


START TRANSACTION;

-- isActive must not be NULL (must fail)
INSERT INTO orchids.location (locationName, isActive)
VALUES ('Garden', NULL);

ROLLBACK;
