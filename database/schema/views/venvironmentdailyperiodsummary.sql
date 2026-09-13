CREATE OR REPLACE VIEW `venvironmentdailyperiodsummary`
AS SELECT `venvironmentreadingperiod`.`locationName`
AS `locationName`,`venvironmentreadingperiod`.`periodCode`
AS `periodCode`,`venvironmentreadingperiod`.`periodName`
AS `periodName`,`venvironmentreadingperiod`.`periodDate`
AS `periodDate`,count(0)
AS `readingCount`,round(avg(`venvironmentreadingperiod`.`temperatureCelsius`),1)
AS `averageTemperatureCelsius`,round(avg(`venvironmentreadingperiod`.`relativeHumidity`),1)
AS `averageRelativeHumidity`,min(`venvironmentreadingperiod`.`readingDateTime`)
AS `firstReadingDateTime`,max(`venvironmentreadingperiod`.`readingDateTime`)
AS `lastReadingDateTime` FROM `venvironmentreadingperiod` group by `venvironmentreadingperiod`.`locationName`,`venvironmentreadingperiod`.`periodCode`,`venvironmentreadingperiod`.`periodName`,`venvironmentreadingperiod`.`periodDate`

