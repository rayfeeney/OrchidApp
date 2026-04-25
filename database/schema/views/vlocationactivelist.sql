CREATE OR REPLACE VIEW `vlocationactivelist`
AS SELECT `location`.`locationId`
AS `locationId`,`location`.`locationName`
AS `locationName`,`location`.`locationTypeCode`
AS `locationTypeCode`,`location`.`climateCode`
AS `climateCode` FROM `location` WHERE `location`.`isActive` = 1

