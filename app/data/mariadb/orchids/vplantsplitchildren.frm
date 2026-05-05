TYPE=VIEW
query=select `ps`.`parentPlantId` AS `parentPlantId`,`child`.`plantId` AS `childPlantId`,`child`.`plantTag` AS `plantTag`,`child`.`acquisitionDate` AS `acquisitionDate` from ((`orchids`.`plantsplit` `ps` join `orchids`.`plantsplitchild` `psc` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) join `orchids`.`plant` `child` on(`child`.`plantId` = `psc`.`childPlantId`))
md5=e462b45b25d6c54b62e17367959c1bad
updatable=1
algorithm=0
definer_user=orchid
definer_host=localhost
suid=2
with_check_option=0
timestamp=0001778010533406799
create-version=2
source=SELECT `ps`.`parentPlantId`\nAS `parentPlantId`,`child`.`plantId`\nAS `childPlantId`,`child`.`plantTag`\nAS `plantTag`,`child`.`acquisitionDate`\nAS `acquisitionDate` FROM ((`plantsplit` `ps` join `plantsplitchild` `psc` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) join `plant` `child` on(`child`.`plantId` = `psc`.`childPlantId`))
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `ps`.`parentPlantId` AS `parentPlantId`,`child`.`plantId` AS `childPlantId`,`child`.`plantTag` AS `plantTag`,`child`.`acquisitionDate` AS `acquisitionDate` from ((`orchids`.`plantsplit` `ps` join `orchids`.`plantsplitchild` `psc` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) join `orchids`.`plant` `child` on(`child`.`plantId` = `psc`.`childPlantId`))
mariadb-version=101116
