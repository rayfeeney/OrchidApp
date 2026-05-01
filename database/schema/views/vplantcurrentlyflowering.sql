CREATE OR REPLACE VIEW `vplantcurrentlyflowering`
AS SELECT `p`.`plantId`
AS `plantId`,`p`.`plantTag`
AS `plantTag`,`l`.`locationName`
AS `locationName`,`g`.`genusId`
AS `genusId`,`g`.`genusName`
AS `genusName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end
AS `displayName`,`f`.`startDate`
AS `floweringStartDate` FROM (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) join `flowering` `f` on(`f`.`plantId` = `p`.`plantId` and `f`.`isActive` = 1 and `f`.`endDate` is null)) left join `plantlocationhistory` `plh` on(`plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 and `plh`.`endDateTime` is null)) left join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) WHERE `p`.`endDate` is null

