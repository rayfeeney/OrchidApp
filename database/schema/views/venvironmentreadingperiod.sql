CREATE OR REPLACE VIEW `venvironmentreadingperiod`
AS SELECT `er`.`environmentReadingId`
AS `environmentReadingId`,`er`.`sensorName`
AS `sensorName`,`es`.`locationName`
AS `locationName`,`er`.`readingDateTime`
AS `readingDateTime`,`epr`.`periodCode`
AS `periodCode`,`epr`.`periodName`
AS `periodName`,case when `epr`.`endTime` > `epr`.`startTime` then cast(`er`.`readingDateTime`
AS date) when cast(`er`.`readingDateTime`
AS time) >= `epr`.`startTime` then cast(`er`.`readingDateTime`
AS date) else cast(`er`.`readingDateTime`
AS date) - interval 1 day end
AS `periodDate`,`er`.`temperatureCelsius`
AS `temperatureCelsius`,`er`.`relativeHumidity`
AS `relativeHumidity` FROM ((`environmentreading` `er` join `environmentsensor` `es` on(`es`.`sensorName` = `er`.`sensorName` and `es`.`isActive` = 1 and cast(`er`.`readingDateTime`
AS date) >= `es`.`effectiveFromDate` and (`es`.`effectiveToDate` is null or cast(`er`.`readingDateTime`
AS date) < `es`.`effectiveToDate`))) join `environmentperiodrule` `epr` on(`epr`.`isActive` = 1 and cast(`er`.`readingDateTime`
AS date) >= `epr`.`effectiveFromDate` and (`epr`.`effectiveToDate` is null or cast(`er`.`readingDateTime`
AS date) < `epr`.`effectiveToDate`) and (`epr`.`endTime` > `epr`.`startTime` and cast(`er`.`readingDateTime`
AS time) >= `epr`.`startTime` and cast(`er`.`readingDateTime`
AS time) < `epr`.`endTime` or `epr`.`endTime` < `epr`.`startTime` and (cast(`er`.`readingDateTime`
AS time) >= `epr`.`startTime` or cast(`er`.`readingDateTime`
AS time) < `epr`.`endTime`)))) WHERE `es`.`locationName` is not null

