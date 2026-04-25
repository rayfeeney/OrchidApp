CREATE OR REPLACE VIEW `vplantcurrentlocation`
AS SELECT `plh`.`plantLocationHistoryId`
AS `plantLocationHistoryId`,`plant`.`plantId`
AS `plantId`,`loc`.`locationId`
AS `locationId`,`loc`.`locationName`
AS `locationName`,`loc`.`locationTypeCode`
AS `locationTypeCode`,`plh`.`startDateTime`
AS `locationStartDateTime`,`plant`.`plantTag`
AS `plantTag`,`plant`.`plantName`
AS `plantName`,`taxon`.`taxonId`
AS `taxonId`,`genus`.`genusName`
AS `genusName`,`genus`.`isActive`
AS `genusIsActive`,case when `taxon`.`isSystemManaged` = 1 then concat(`genus`.`genusName`,' sp.') when `taxon`.`speciesName` is not null then concat(`genus`.`genusName`,' ',`taxon`.`speciesName`) when `taxon`.`hybridName` is not null then concat(`genus`.`genusName`,' ',`taxon`.`hybridName`) else `genus`.`genusName` end
AS `displayName`,`plant`.`endDate`
AS `plantEndDate`,`plh`.`RowOrder`
AS `RowOrder` FROM ((((`plant` join `taxon` on(`taxon`.`taxonId` = `plant`.`taxonId`)) join `genus` on(`genus`.`genusId` = `taxon`.`genusId`)) left join (SELECT `sub`.`plantLocationHistoryId`
AS `plantLocationHistoryId`,`sub`.`plantId`
AS `plantId`,`sub`.`locationId`
AS `locationId`,`sub`.`startDateTime`
AS `startDateTime`,`sub`.`endDateTime`
AS `endDateTime`,`sub`.`moveReasonCode`
AS `moveReasonCode`,`sub`.`moveReasonNotes`
AS `moveReasonNotes`,`sub`.`plantLocationNotes`
AS `plantLocationNotes`,`sub`.`createdDateTime`
AS `createdDateTime`,`sub`.`isActive`
AS `isActive`,`sub`.`updatedDateTime`
AS `updatedDateTime`,`sub`.`RowOrder`
AS `RowOrder` FROM (SELECT `lochistory`.`plantLocationHistoryId`
AS `plantLocationHistoryId`,`lochistory`.`plantId`
AS `plantId`,`lochistory`.`locationId`
AS `locationId`,`lochistory`.`startDateTime`
AS `startDateTime`,`lochistory`.`endDateTime`
AS `endDateTime`,`lochistory`.`moveReasonCode`
AS `moveReasonCode`,`lochistory`.`moveReasonNotes`
AS `moveReasonNotes`,`lochistory`.`plantLocationNotes`
AS `plantLocationNotes`,`lochistory`.`createdDateTime`
AS `createdDateTime`,`lochistory`.`isActive`
AS `isActive`,`lochistory`.`updatedDateTime`
AS `updatedDateTime`,row_number() over ( partition by `lochistory`.`plantId` order by `lochistory`.`startDateTime` desc)
AS `RowOrder` FROM `plantlocationhistory` `lochistory` WHERE `lochistory`.`isActive` = 1) `sub` WHERE `sub`.`RowOrder` = 1) `plh` on(`plant`.`plantId` = `plh`.`plantId`)) left join `location` `loc` on(`loc`.`locationId` = `plh`.`locationId` and `loc`.`isActive` = 1)) WHERE `plant`.`isActive` = 1

