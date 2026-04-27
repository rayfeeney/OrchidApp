ALTER TABLE repotting
  DROP FOREIGN KEY fk_repotting_old_growthmedium,
  DROP FOREIGN KEY fk_repotting_new_growthmedium;

-- Step 2: drop supporting indexes
ALTER TABLE repotting
  DROP INDEX fk_repotting_old_growthmedium,
  DROP INDEX fk_repotting_new_growthmedium;

-- Step 3: recreate with correct naming + behaviour
ALTER TABLE repotting
  ADD CONSTRAINT fkRepottingOldGrowthMedium
  FOREIGN KEY (oldGrowthMediumId)
  REFERENCES growthmedium(growthMediumId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

ALTER TABLE repotting
  ADD CONSTRAINT fkRepottingNewGrowthMedium
  FOREIGN KEY (newGrowthMediumId)
  REFERENCES growthmedium(growthMediumId)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;