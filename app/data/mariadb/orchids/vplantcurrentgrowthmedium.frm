TYPE=VIEW
query=select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `orchids`.`repotting`.`repottingId` AS `repottingId`,`orchids`.`repotting`.`plantId` AS `plantId`,`orchids`.`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`orchids`.`repotting`.`potSize` AS `potSize`,`orchids`.`repotting`.`repottingNotes` AS `repottingNotes`,`orchids`.`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `orchids`.`repotting`.`plantId` order by `orchids`.`repotting`.`repotDate` desc,`orchids`.`repotting`.`repottingId` desc) AS `rn` from `orchids`.`repotting` where `orchids`.`repotting`.`isActive` = 1) `r` join `orchids`.`growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1
md5=91b3cc815e26e2542aeb0e846c7dafc0
updatable=1
algorithm=0
definer_user=orchid
definer_host=localhost
suid=2
with_check_option=0
timestamp=0001778087547215120
create-version=2
source=SELECT `r`.`plantId`\nAS `plantId`,`r`.`newGrowthMediumId`\nAS `growthMediumId`,`gm`.`name`\nAS `growthMediumName`,`r`.`potSize`\nAS `potSize`,`r`.`repottingNotes`\nAS `repottingNotes`,`r`.`repotDate`\nAS `repotDate` FROM ((SELECT `repotting`.`repottingId`\nAS `repottingId`,`repotting`.`plantId`\nAS `plantId`,`repotting`.`newGrowthMediumId`\nAS `newGrowthMediumId`,`repotting`.`potSize`\nAS `potSize`,`repotting`.`repottingNotes`\nAS `repottingNotes`,`repotting`.`repotDate`\nAS `repotDate`,row_number() over ( partition by `repotting`.`plantId` order by `repotting`.`repotDate` desc,`repotting`.`repottingId` desc)\nAS `rn` FROM `repotting` WHERE `repotting`.`isActive` = 1) `r` join `growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) WHERE `r`.`rn` = 1
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `orchids`.`repotting`.`repottingId` AS `repottingId`,`orchids`.`repotting`.`plantId` AS `plantId`,`orchids`.`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`orchids`.`repotting`.`potSize` AS `potSize`,`orchids`.`repotting`.`repottingNotes` AS `repottingNotes`,`orchids`.`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `orchids`.`repotting`.`plantId` order by `orchids`.`repotting`.`repotDate` desc,`orchids`.`repotting`.`repottingId` desc) AS `rn` from `orchids`.`repotting` where `orchids`.`repotting`.`isActive` = 1) `r` join `orchids`.`growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1
mariadb-version=101116
