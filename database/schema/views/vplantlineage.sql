CREATE OR REPLACE VIEW `vplantlineage`
AS SELECT `c`.`childPlantId`
AS `childPlantId`,`s`.`parentPlantId`
AS `parentPlantId` FROM (`plantsplitchild` `c` join `plantsplit` `s` on(`c`.`plantSplitId` = `s`.`plantSplitId`)) WHERE `c`.`isActive` = 1 union all SELECT `p`.`childPlantId`
AS `childPlantId`,`p`.`parentPlantId`
AS `parentPlantId` FROM `plantpropagation` `p` WHERE `p`.`isActive` = 1

