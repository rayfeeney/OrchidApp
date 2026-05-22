TYPE=VIEW
query=select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `orchids`.`repotting`.`repottingId` AS `repottingId`,`orchids`.`repotting`.`plantId` AS `plantId`,`orchids`.`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`orchids`.`repotting`.`potSize` AS `potSize`,`orchids`.`repotting`.`repottingNotes` AS `repottingNotes`,`orchids`.`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `orchids`.`repotting`.`plantId` order by `orchids`.`repotting`.`repotDate` desc,`orchids`.`repotting`.`repottingId` desc) AS `rn` from `orchids`.`repotting` where `orchids`.`repotting`.`isActive` = 1) `r` join `orchids`.`growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1
md5=91b3cc815e26e2542aeb0e846c7dafc0
updatable=1
algorithm=0
definer_user=orchid
definer_host=localhost
suid=1
with_check_option=0
timestamp=0001779391637515409
create-version=2
source=select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `repotting`.`repottingId` AS `repottingId`,`repotting`.`plantId` AS `plantId`,`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`repotting`.`potSize` AS `potSize`,`repotting`.`repottingNotes` AS `repottingNotes`,`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `repotting`.`plantId` order by `repotting`.`repotDate` desc,`repotting`.`repottingId` desc) AS `rn` from `repotting` where `repotting`.`isActive` = 1) `r` join `growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `r`.`plantId` AS `plantId`,`r`.`newGrowthMediumId` AS `growthMediumId`,`gm`.`name` AS `growthMediumName`,`r`.`potSize` AS `potSize`,`r`.`repottingNotes` AS `repottingNotes`,`r`.`repotDate` AS `repotDate` from ((select `orchids`.`repotting`.`repottingId` AS `repottingId`,`orchids`.`repotting`.`plantId` AS `plantId`,`orchids`.`repotting`.`newGrowthMediumId` AS `newGrowthMediumId`,`orchids`.`repotting`.`potSize` AS `potSize`,`orchids`.`repotting`.`repottingNotes` AS `repottingNotes`,`orchids`.`repotting`.`repotDate` AS `repotDate`,row_number() over ( partition by `orchids`.`repotting`.`plantId` order by `orchids`.`repotting`.`repotDate` desc,`orchids`.`repotting`.`repottingId` desc) AS `rn` from `orchids`.`repotting` where `orchids`.`repotting`.`isActive` = 1) `r` join `orchids`.`growthmedium` `gm` on(`gm`.`growthMediumId` = `r`.`newGrowthMediumId`)) where `r`.`rn` = 1
mariadb-version=101116
