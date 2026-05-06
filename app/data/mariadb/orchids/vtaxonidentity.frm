TYPE=VIEW
query=select `t`.`taxonId` AS `taxonId`,`t`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`t`.`speciesName` AS `speciesName`,`t`.`hybridName` AS `hybridName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,\' sp.\') when `t`.`speciesName` is null and `t`.`hybridName` is null then `g`.`genusName` when `t`.`speciesName` is not null then concat(`g`.`genusName`,\' \',`t`.`speciesName`) else concat(`g`.`genusName`,\' \',`t`.`hybridName`) end AS `displayName`,`t`.`taxonNotes` AS `taxonNotes`,`t`.`isActive` AS `isActive`,`t`.`isSystemManaged` AS `isSystemManaged`,`t`.`growthCode` AS `growthCode`,`t`.`growthNotes` AS `growthNotes` from (`orchids`.`taxon` `t` join `orchids`.`genus` `g` on(`g`.`genusId` = `t`.`genusId`))
md5=1de86fae9fc12de520c95ac2967738f5
updatable=1
algorithm=0
definer_user=orchid
definer_host=localhost
suid=2
with_check_option=0
timestamp=0001778087548025314
create-version=2
source=SELECT `t`.`taxonId`\nAS `taxonId`,`t`.`genusId`\nAS `genusId`,`g`.`genusName`\nAS `genusName`,`g`.`isActive`\nAS `genusIsActive`,`t`.`speciesName`\nAS `speciesName`,`t`.`hybridName`\nAS `hybridName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,\' sp.\') when `t`.`speciesName` is null and `t`.`hybridName` is null then `g`.`genusName` when `t`.`speciesName` is not null then concat(`g`.`genusName`,\' \',`t`.`speciesName`) else concat(`g`.`genusName`,\' \',`t`.`hybridName`) end\nAS `displayName`,`t`.`taxonNotes`\nAS `taxonNotes`,`t`.`isActive`\nAS `isActive`,`t`.`isSystemManaged`\nAS `isSystemManaged`,`t`.`growthCode`\nAS `growthCode`,`t`.`growthNotes`\nAS `growthNotes` FROM (`taxon` `t` join `genus` `g` on(`g`.`genusId` = `t`.`genusId`))
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `t`.`taxonId` AS `taxonId`,`t`.`genusId` AS `genusId`,`g`.`genusName` AS `genusName`,`g`.`isActive` AS `genusIsActive`,`t`.`speciesName` AS `speciesName`,`t`.`hybridName` AS `hybridName`,case when `t`.`isSystemManaged` = 1 then concat(`g`.`genusName`,\' sp.\') when `t`.`speciesName` is null and `t`.`hybridName` is null then `g`.`genusName` when `t`.`speciesName` is not null then concat(`g`.`genusName`,\' \',`t`.`speciesName`) else concat(`g`.`genusName`,\' \',`t`.`hybridName`) end AS `displayName`,`t`.`taxonNotes` AS `taxonNotes`,`t`.`isActive` AS `isActive`,`t`.`isSystemManaged` AS `isSystemManaged`,`t`.`growthCode` AS `growthCode`,`t`.`growthNotes` AS `growthNotes` from (`orchids`.`taxon` `t` join `orchids`.`genus` `g` on(`g`.`genusId` = `t`.`genusId`))
mariadb-version=101116
