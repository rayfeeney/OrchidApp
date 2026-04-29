CREATE OR REPLACE VIEW `vplantstatus`
AS SELECT `p`.`plantId`
AS `plantId`,`p`.`acquisitionDate`
AS `acquisitionDate`,`p`.`acquisitionSource`
AS `acquisitionSource`,`p`.`endDate`
AS `endDate`,`p`.`plantTag`
AS `plantTag`,trim(case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end)
AS `displayName`,`t`.`isActive`
AS `taxonIsActive`,`g`.`isActive`
AS `genusIsActive`,`l`.`locationName`
AS `locationName`,`lf`.`startDate`
AS `lastFloweringDate`,`lr`.`repotDate`
AS `lastRepotDate`,`gm`.`name`
AS `currentGrowthMediumName`,`lfeed`.`eventDateTime`
AS `lastFeedDateTime`,`ot`.`displayName`
AS `lastFeedTypeDisplayName`,case when exists(SELECT 1 FROM `vplantlineage` `lp` WHERE `lp`.`childPlantId` = `p`.`plantId` limit 1) then 1 else 0 end
AS `hasParent`,(SELECT `lp`.`parentPlantId` FROM `vplantlineage` `lp` WHERE `lp`.`childPlantId` = `p`.`plantId` limit 1)
AS `parentPlantId`,(SELECT `parent`.`plantTag` FROM (`vplantlineage` `lp` join `plant` `parent` on(`parent`.`plantId` = `lp`.`parentPlantId`)) WHERE `lp`.`childPlantId` = `p`.`plantId` limit 1)
AS `parentPlantTag`,case when exists(SELECT 1 FROM `vplantlineage` `lc` WHERE `lc`.`parentPlantId` = `p`.`plantId` limit 1) then 1 else 0 end
AS `hasChildren` FROM (((((((((`plant` `p` left join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) left join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join `plantlocationhistory` `clh` on(`clh`.`plantLocationHistoryId` = (SELECT `plh`.`plantLocationHistoryId` FROM `plantlocationhistory` `plh` WHERE `plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 order by `plh`.`startDateTime` desc limit 1))) left join `location` `l` on(`l`.`locationId` = `clh`.`locationId`)) left join `flowering` `lf` on(`lf`.`floweringId` = (SELECT `f`.`floweringId` FROM `flowering` `f` WHERE `f`.`plantId` = `p`.`plantId` and `f`.`isActive` = 1 order by `f`.`startDate` desc limit 1))) left join `repotting` `lr` on(`lr`.`repottingId` = (SELECT `r`.`repottingId` FROM `repotting` `r` WHERE `r`.`plantId` = `p`.`plantId` and `r`.`isActive` = 1 order by `r`.`repotDate` desc limit 1))) left join `growthmedium` `gm` on(`gm`.`growthMediumId` = `lr`.`newGrowthMediumId`)) left join `plantevent` `lfeed` on(`lfeed`.`plantEventId` = (SELECT `pe`.`plantEventId` FROM (`plantevent` `pe` join `observationtype` `o` on(`o`.`Id` = `pe`.`observationTypeId` and `o`.`isActive` = 1 and `o`.`typeCode` like 'OBS_FEED%')) WHERE `pe`.`plantId` = `p`.`plantId` and `pe`.`isActive` = 1 order by `pe`.`eventDateTime` desc limit 1))) left join `observationtype` `ot` on(`ot`.`Id` = `lfeed`.`observationTypeId`)) WHERE `p`.`isActive` = 1

