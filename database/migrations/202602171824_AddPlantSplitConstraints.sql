ALTER TABLE orchids.plantsplit
  ADD CONSTRAINT uxPlantSplit_parentPlantId
  UNIQUE (parentPlantId);
