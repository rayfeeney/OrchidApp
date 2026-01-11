-- species_NotNull.sql
START TRANSACTION;

-- genus must not be NULL (must fail)
INSERT INTO orchids.species (genus, isActive)
VALUES (NULL, 1);

-- isActive must not be NULL (must fail)
INSERT INTO orchids.species (speciesId, genus, isActive)
VALUES ('Dendrobium', NULL);


ROLLBACK;
