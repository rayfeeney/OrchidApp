CREATE OR REPLACE VIEW `venvironmentlastsevendayssummary`
AS SELECT `actual`.`locationName`
AS `locationName`,`actual`.`averageDayTemperatureCelsius`
AS `averageDayTemperatureCelsius`,`target`.`expectedDayTemperatureCelsius`
AS `expectedDayTemperatureCelsius`,`actual`.`averageNightTemperatureCelsius`
AS `averageNightTemperatureCelsius`,`target`.`expectedNightTemperatureCelsius`
AS `expectedNightTemperatureCelsius`,`actual`.`averageRelativeHumidity`
AS `averageRelativeHumidity`,`target`.`expectedRelativeHumidity`
AS `expectedRelativeHumidity`,`actual`.`readingCount`
AS `readingCount`,`actual`.`firstReadingDateTime`
AS `firstReadingDateTime`,`actual`.`lastReadingDateTime`
AS `lastReadingDateTime` FROM ((SELECT `venvironmentreadingperiod`.`locationName`
AS `locationName`,round(avg(case when `venvironmentreadingperiod`.`periodCode` = 'DAY' then `venvironmentreadingperiod`.`temperatureCelsius` else NULL end),1)
AS `averageDayTemperatureCelsius`,round(avg(case when `venvironmentreadingperiod`.`periodCode` = 'NIGHT' then `venvironmentreadingperiod`.`temperatureCelsius` else NULL end),1)
AS `averageNightTemperatureCelsius`,round(avg(`venvironmentreadingperiod`.`relativeHumidity`),1)
AS `averageRelativeHumidity`,count(0)
AS `readingCount`,min(`venvironmentreadingperiod`.`readingDateTime`)
AS `firstReadingDateTime`,max(`venvironmentreadingperiod`.`readingDateTime`)
AS `lastReadingDateTime` FROM `venvironmentreadingperiod` WHERE `venvironmentreadingperiod`.`readingDateTime` >= curdate() - interval 7 day and `venvironmentreadingperiod`.`readingDateTime` < curdate() + interval 1 day group by `venvironmentreadingperiod`.`locationName`) `actual` join `environmenttargetrule` `target` on(`target`.`locationName` = `actual`.`locationName` and `target`.`monthNumber` = month(curdate()) and `target`.`isActive` = 1 and curdate() >= `target`.`effectiveFromDate` and (`target`.`effectiveToDate` is null or curdate() < `target`.`effectiveToDate`)))

