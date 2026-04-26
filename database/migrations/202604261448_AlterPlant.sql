-- Step 1: drop FK (correct name)
ALTER TABLE plant
  DROP FOREIGN KEY fkPlantTaxon;

-- Step 2: drop wrong index
ALTER TABLE plant
  DROP INDEX ixPlantTaxonId;

-- Step 3: recreate FK (creates correct index name)
ALTER TABLE plant
  ADD CONSTRAINT fkPlantTaxon
  FOREIGN KEY (taxonId)
  REFERENCES taxon(taxonId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;