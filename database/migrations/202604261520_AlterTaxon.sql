-- Step 1: drop FK
ALTER TABLE taxon
  DROP FOREIGN KEY fkTaxonGenus;

-- Step 2: drop incorrect index
ALTER TABLE taxon
  DROP INDEX ixTaxonGenusId;

-- Step 3: recreate FK (correct naming + behaviour)
ALTER TABLE taxon
  ADD CONSTRAINT fkTaxonGenus
  FOREIGN KEY (genusId)
  REFERENCES genus(genusId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;