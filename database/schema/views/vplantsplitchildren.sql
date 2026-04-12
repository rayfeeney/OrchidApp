CREATE OR REPLACE VIEW `vplantsplitchildren` AS select `ps`.`parentPlantId` AS `parentPlantId`,`child`.`plantId` AS `childPlantId`,`child`.`plantTag` AS `plantTag`,`child`.`acquisitionDate` AS `acquisitionDate` from ((`plantsplit` `ps` join `plantsplitchild` `psc` on((`psc`.`plantSplitId` = `ps`.`plantSplitId`))) join `plant` `child` on((`child`.`plantId` = `psc`.`childPlantId`)));

