CREATE OR REPLACE VIEW `vplantactivecurrentlocation`
AS SELECT `p`.`plantId`
AS `plantId`,`t`.`taxonId`
AS `taxonId`,`p`.`plantTag`
AS `plantTag`,`p`.`plantName`
AS `plantName`,`g`.`genusName`
AS `genusName`,`g`.`isActive`
AS `genusIsActive`,`t`.`isActive`
AS `taxonIsActive`,`loc`.`locationId`
AS `locationId`,`loc`.`locationName`
AS `locationName`,`loc`.`locationTypeCode`
AS `locationTypeCode`,`plh`.`startDateTime`
AS `locationStartDateTime`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,' sp.') when `t`.`speciesName` is not null then concat(`g`.`genusName`,' ',`t`.`speciesName`) when `t`.`hybridName` is not null then concat(`g`.`genusName`,' ',`t`.`hybridName`) else `g`.`genusName` end
AS `displayName`,`pp`.`fileName`
AS `heroFileName`,`pp`.`thumbnailFileName`
AS `heroThumbnailFileName` FROM (((((`plant` `p` join `taxon` `t` on(`t`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `t`.`genusId`)) left join (SELECT `sub`.`plantId`
AS `plantId`,`sub`.`locationId`
AS `locationId`,`sub`.`startDateTime`
AS `startDateTime` FROM (SELECT `lochistory`.`plantId`
AS `plantId`,`lochistory`.`locationId`
AS `locationId`,`lochistory`.`startDateTime`
AS `startDateTime`,row_number() over ( partition by `lochistory`.`plantId` order by `lochistory`.`startDateTime` desc)
AS `RowOrder` FROM `plantlocationhistory` `lochistory` WHERE `lochistory`.`isActive` = 1) `sub` WHERE `sub`.`RowOrder` = 1) `plh` on(`p`.`plantId` = `plh`.`plantId`)) left join `location` `loc` on(`loc`.`locationId` = `plh`.`locationId` and `loc`.`isActive` = 1)) left join `plantphoto` `pp` on(`pp`.`plantId` = `p`.`plantId` and `pp`.`isHero` = 1 and `pp`.`isActive` = 1)) WHERE `p`.`isActive` = 1 and `p`.`endDate` is null

