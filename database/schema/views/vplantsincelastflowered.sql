CREATE OR REPLACE VIEW `vplantsincelastflowered`
AS SELECT `p`.`plantId`
AS `plantId`,`p`.`plantTag`
AS `plantTag`,`p`.`acquisitionDate`
AS `acquisitionDate`,`l`.`locationName`
AS `locationName`,`g`.`genusId`
AS `genusId`,`g`.`genusName`
AS `genusName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end
AS `displayName`,`lastflower`.`lastFlowerEndDate`
AS `lastFlowerEndDate`,timestampdiff(MONTH,`lastflower`.`lastFlowerEndDate`,curdate())
AS `monthsSinceFlower` FROM (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (SELECT `f`.`plantId`
AS `plantId`,max(`f`.`endDate`)
AS `lastFlowerEndDate` FROM `flowering` `f` WHERE `f`.`isActive` = 1 and `f`.`endDate` is not null group by `f`.`plantId`) `lastflower` on(`lastflower`.`plantId` = `p`.`plantId`)) left join `plantlocationhistory` `plh` on(`plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 and `plh`.`endDateTime` is null)) left join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) WHERE `p`.`endDate` is null and !exists(SELECT 1 FROM `flowering` `f2` WHERE `f2`.`plantId` = `p`.`plantId` and `f2`.`isActive` = 1 and `f2`.`endDate` is null limit 1)

