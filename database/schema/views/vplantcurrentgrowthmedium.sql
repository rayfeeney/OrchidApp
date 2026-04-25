CREATE OR REPLACE VIEW `vplantcurrentgrowthmedium`
AS SELECT `r`.`plantId`
AS `plantId`,`r`.`newGrowthMediumId`
AS `growthMediumId`,`gm`.`name`
AS `growthMediumName`,`r`.`potSize`
AS `potSize`,`r`.`repottingNotes`
AS `repottingNotes`,`r`.`repotDate`
AS `repotDate` FROM ((SELECT `repotting`.`repottingId`
AS `repottingId`,`repotting`.`plantId`
AS `plantId`,`repotting`.`newGrowthMediumId`
AS `newGrowthMediumId`,`repotting`.`potSize`
AS `potSize`,`repotting`.`repottingNotes`
AS `repottingNotes`,`repotting`.`repotDate`
AS `repotDate`,row_number() over ( partition by `repotting`.`plantId` order by `repotting`.`repotDate` desc,`repotting`.`repottingId` desc)
AS `rn` FROM `repotting` WHERE `repotting`.`isActive` = 1) `r` join `growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) WHERE `r`.`rn` = 1

