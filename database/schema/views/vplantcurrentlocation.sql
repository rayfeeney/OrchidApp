CREATE VIEW `vplantcurrentlocation` AS select `plh`.`plantId` AS `plantId`,`plh`.`locationId` AS `locationId`,`l`.`locationName` AS `locationName`,`l`.`locationTypeCode` AS `locationTypeCode`,`plh`.`startDateTime` AS `locationStartDateTime` from (`plantlocationhistory` `plh` join `location` `l` on((`l`.`locationId` = `plh`.`locationId`))) where (`plh`.`endDateTime` is null);

