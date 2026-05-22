TYPE=VIEW
query=select `orchids`.`location`.`locationId` AS `locationId`,`orchids`.`location`.`locationName` AS `locationName`,`orchids`.`location`.`locationTypeCode` AS `locationTypeCode`,`orchids`.`location`.`climateCode` AS `climateCode` from `orchids`.`location` where `orchids`.`location`.`isActive` = 1
md5=1e3ce6540a8fdd0c72b37273e4637241
updatable=1
algorithm=0
definer_user=orchid
definer_host=localhost
suid=1
with_check_option=0
timestamp=0001779391637492325
create-version=2
source=select `location`.`locationId` AS `locationId`,`location`.`locationName` AS `locationName`,`location`.`locationTypeCode` AS `locationTypeCode`,`location`.`climateCode` AS `climateCode` from `location` where `location`.`isActive` = 1
client_cs_name=utf8mb4
connection_cl_name=utf8mb4_general_ci
view_body_utf8=select `orchids`.`location`.`locationId` AS `locationId`,`orchids`.`location`.`locationName` AS `locationName`,`orchids`.`location`.`locationTypeCode` AS `locationTypeCode`,`orchids`.`location`.`climateCode` AS `climateCode` from `orchids`.`location` where `orchids`.`location`.`isActive` = 1
mariadb-version=101116
