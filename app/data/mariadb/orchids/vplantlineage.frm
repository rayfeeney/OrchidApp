TYPE=VIEW
query=select `c`.`childPlantId` AS `childPlantId`,`s`.`parentPlantId` AS `parentPlantId`,\'Split\' AS `relationshipType` from (`orchids`.`plantsplitchild` `c` join `orchids`.`plantsplit` `s` on(`c`.`plantSplitId` = `s`.`plantSplitId`)) where `c`.`isActive` = 1 union all select `p`.`childPlantId` AS `childPlantId`,`p`.`parentPlantId` AS `parentPlantId`,`pt`.`propagationTypeName` AS `relationshipType` from (`orchids`.`plantpropagation` `p` join `orchids`.`propagationtype` `pt` on(`pt`.`propagationTypeId` = `p`.`propagationTypeId`)) where `p`.`isActive` = 1
md5=dc45ee692f120c6188a6985e199bba56
updatable=0
algorithm=0
definer_user=orchid
definer_host=localhost
suid=2
with_check_option=0
timestamp=0001778087547577067
create-version=2
source=SELECT `c`.`childPlantId`\nAS `childPlantId`,`s`.`parentPlantId`\nAS `parentPlantId`,\'Split\'\nAS `relationshipType` FROM (`plantsplitchild` `c` join `plantsplit` `s` on(`c`.`plantSplitId` = `s`.`plantSplitId`)) WHERE `c`.`isActive` = 1 union all SELECT `p`.`childPlantId`\nAS `childPlantId`,`p`.`parentPlantId`\nAS `parentPlantId`,`pt`.`propagationTypeName`\nAS `relationshipType` FROM (`plantpropagation` `p` join `propagationtype` `pt` on(`pt`.`propagationTypeId` = `p`.`propagationTypeId`)) WHERE `p`.`isActive` = 1
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `c`.`childPlantId` AS `childPlantId`,`s`.`parentPlantId` AS `parentPlantId`,\'Split\' AS `relationshipType` from (`orchids`.`plantsplitchild` `c` join `orchids`.`plantsplit` `s` on(`c`.`plantSplitId` = `s`.`plantSplitId`)) where `c`.`isActive` = 1 union all select `p`.`childPlantId` AS `childPlantId`,`p`.`parentPlantId` AS `parentPlantId`,`pt`.`propagationTypeName` AS `relationshipType` from (`orchids`.`plantpropagation` `p` join `orchids`.`propagationtype` `pt` on(`pt`.`propagationTypeId` = `p`.`propagationTypeId`)) where `p`.`isActive` = 1
mariadb-version=101116
