CREATE OR REPLACE VIEW `vplantsplitchildren`
AS SELECT `ps`.`parentPlantId`
AS `parentPlantId`,`child`.`plantId`
AS `childPlantId`,`child`.`plantTag`
AS `plantTag`,`child`.`acquisitionDate`
AS `acquisitionDate` FROM ((`plantsplit` `ps` join `plantsplitchild` `psc` on(`psc`.`plantSplitId` = `ps`.`plantSplitId`)) join `plant` `child` on(`child`.`plantId` = `psc`.`childPlantId`))

