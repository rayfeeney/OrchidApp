CREATE OR REPLACE VIEW `vlocationactivelist` AS select `location`.`locationId` AS `locationId`,`location`.`locationName` AS `locationName`,`location`.`locationTypeCode` AS `locationTypeCode`,`location`.`climateCode` AS `climateCode` from `location` where (`location`.`isActive` = 1);

