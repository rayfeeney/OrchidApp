START TRANSACTION;

-- This must fail
INSERT INTO species (genus, isActive)
VALUES ('Gorilla', 2);

-- Show it failed
SELECT speciesId, genus
FROM orchids.species; 

ROLLBACK;