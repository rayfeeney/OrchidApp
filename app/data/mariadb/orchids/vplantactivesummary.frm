TYPE=VIEW
query=select `p`.`plantId` AS `plantId`,`s`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`s`.`isActive` AS `taxonIsActive`,`s`.`speciesName` AS `speciesName`,`s`.`hybridName` AS `hybridName`,case when `s`.`isSystemManaged` = 1 then concat(`g`.`genusName`,\' sp.\') when `s`.`speciesName` is not null then concat(`g`.`genusName`,\' \',`s`.`speciesName`) when `s`.`hybridName` is not null then concat(`g`.`genusName`,\' \',`s`.`hybridName`) else `g`.`genusName` end AS `displayName` from ((`orchids`.`plant` `p` join `orchids`.`taxon` `s` on(`s`.`taxonId` = `p`.`taxonId`)) join `orchids`.`genus` `g` on(`g`.`genusId` = `s`.`genusId`)) where `p`.`isActive` = 1 and `p`.`endDate` is null
md5=13cce6486c9e0b886705f638701e63c1
updatable=1
algorithm=0
definer_user=orchid
definer_host=localhost
suid=2
with_check_option=0
timestamp=0001778010532618393
create-version=2
source=SELECT `p`.`plantId`\nAS `plantId`,`s`.`taxonId`\nAS `taxonId`,`p`.`plantTag`\nAS `plantTag`,`p`.`plantName`\nAS `plantName`,`p`.`acquisitionDate`\nAS `acquisitionDate`,`p`.`acquisitionSource`\nAS `acquisitionSource`,`g`.`genusName`\nAS `genusName`,`g`.`isActive`\nAS `genusIsActive`,`s`.`isActive`\nAS `taxonIsActive`,`s`.`speciesName`\nAS `speciesName`,`s`.`hybridName`\nAS `hybridName`,case when `s`.`isSystemManaged` = 1 then concat(`g`.`genusName`,\' sp.\') when `s`.`speciesName` is not null then concat(`g`.`genusName`,\' \',`s`.`speciesName`) when `s`.`hybridName` is not null then concat(`g`.`genusName`,\' \',`s`.`hybridName`) else `g`.`genusName` end\nAS `displayName` FROM ((`plant` `p` join `taxon` `s` on(`s`.`taxonId` = `p`.`taxonId`)) join `genus` `g` on(`g`.`genusId` = `s`.`genusId`)) WHERE `p`.`isActive` = 1 and `p`.`endDate` is null
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `p`.`plantId` AS `plantId`,`s`.`taxonId` AS `taxonId`,`p`.`plantTag` AS `plantTag`,`p`.`plantName` AS `plantName`,`p`.`acquisitionDate` AS `acquisitionDate`,`p`.`acquisitionSource` AS `acquisitionSource`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`s`.`isActive` AS `taxonIsActive`,`s`.`speciesName` AS `speciesName`,`s`.`hybridName` AS `hybridName`,case when `s`.`isSystemManaged` = 1 then concat(`g`.`genusName`,\' sp.\') when `s`.`speciesName` is not null then concat(`g`.`genusName`,\' \',`s`.`speciesName`) when `s`.`hybridName` is not null then concat(`g`.`genusName`,\' \',`s`.`hybridName`) else `g`.`genusName` end AS `displayName` from ((`orchids`.`plant` `p` join `orchids`.`taxon` `s` on(`s`.`taxonId` = `p`.`taxonId`)) join `orchids`.`genus` `g` on(`g`.`genusId` = `s`.`genusId`)) where `p`.`isActive` = 1 and `p`.`endDate` is null
mariadb-version=101116
