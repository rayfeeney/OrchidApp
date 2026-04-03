ALTER TABLE plantevent
ADD CONSTRAINT fk_plantevent_observationtype
FOREIGN KEY (observationType)
REFERENCES observationtype(Id)
ON DELETE RESTRICT
ON UPDATE RESTRICT;

ALTER TABLE repotting
ADD CONSTRAINT fk_repotting_old_growthmedium
FOREIGN KEY (oldGrowthMediumId)
REFERENCES growthmedium(growthMediumId)
ON DELETE RESTRICT
ON UPDATE RESTRICT;

ALTER TABLE repotting
ADD CONSTRAINT fk_repotting_new_growthmedium
FOREIGN KEY (newGrowthMediumId)
REFERENCES growthmedium(growthMediumId)
ON DELETE RESTRICT
ON UPDATE RESTRICT;