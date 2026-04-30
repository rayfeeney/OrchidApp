CREATE OR REPLACE VIEW `vplantrepotstatus`
AS SELECT `base`.`plantId`
AS `plantId`,`base`.`plantTag`
AS `plantTag`,`base`.`locationName`
AS `locationName`,`base`.`genusId`
AS `genusId`,`base`.`genusName`
AS `genusName`,`base`.`displayName`
AS `displayName`,`base`.`acquisitionDate`
AS `acquisitionDate`,`base`.`lastRepotDate`
AS `lastRepotDate`,coalesce(`base`.`acquisitionDate`,`base`.`lastRepotDate`)
AS `effectiveRepotDate`,`base`.`monthsSinceRepot`
AS `monthsSinceRepot`,case when `base`.`lastRepotDate` is null and `base`.`acquisitionDate` is null then 'Unknown' when `base`.`lastRepotDate` is not null then 'Repotted' else 'FROM acquisition' end
AS `repotStatus`,case when `base`.`lastRepotDate` is null and `base`.`acquisitionDate` is null then 'No repotting information' else concat(`base`.`monthsSinceRepot`,case when `base`.`monthsSinceRepot` = 1 then ' month since ' else ' months since ' end,case when `base`.`lastRepotDate` is not null then 'repot' else 'acquisition' end,' (',date_format(`base`.`effectiveDate`,'%d/%m/%Y'),')') end
AS `repotSummary` FROM (SELECT `p`.`plantId`
AS `plantId`,`p`.`plantTag`
AS `plantTag`,`l`.`locationName`
AS `locationName`,`g`.`genusName`
AS `genusName`,`g`.`genusId`
AS `genusId`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end
AS `displayName`,`p`.`acquisitionDate`
AS `acquisitionDate`,`repot`.`lastRepotDate`
AS `lastRepotDate`,coalesce(`repot`.`lastRepotDate`,`p`.`acquisitionDate`)
AS `effectiveDate`,timestampdiff(MONTH,coalesce(`repot`.`lastRepotDate`,`p`.`acquisitionDate`),curdate())
AS `monthsSinceRepot` FROM (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (SELECT `r`.`plantId`
AS `plantId`,max(`r`.`repotDate`)
AS `lastRepotDate` FROM `repotting` `r` WHERE `r`.`isActive` = 1 group by `r`.`plantId`) `repot` on(`repot`.`plantId` = `p`.`plantId`)) left join `plantlocationhistory` `plh` on(`plh`.`plantId` = `p`.`plantId` and `plh`.`isActive` = 1 and `plh`.`endDateTime` is null)) left join `location` `l` on(`l`.`locationId` = `plh`.`locationId`)) WHERE `p`.`endDate` is null) `base`

