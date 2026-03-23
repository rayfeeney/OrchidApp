CREATE INDEX ixPlhStatusLookup
ON orchids.plantlocationhistory
    (plantId, isActive, startDateTime DESC, locationId);

CREATE INDEX ixRepotStatusLookup
ON orchids.repotting
    (plantId, isActive, repotDate DESC, newGrowthMediumId);

CREATE INDEX ixFlowerStatusLookup
ON orchids.flowering
    (plantId, isActive, startDate DESC);

CREATE INDEX ixPlantEventStatusLookup
ON orchids.plantevent
    (plantId, isActive, eventDateTime DESC, observationTypeId);