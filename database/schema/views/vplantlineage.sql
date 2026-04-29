CREATE OR REPLACE VIEW `vplantlineage`
AS SELECT `c`.`childPlantId`
AS `childPlantId`,`s`.`parentPlantId`
AS `parentPlantId`,'Split'
AS `relationshipType` FROM (`plantsplitchild` `c` join `plantsplit` `s` on(`c`.`plantSplitId` = `s`.`plantSplitId`)) WHERE `c`.`isActive` = 1 union all SELECT `p`.`childPlantId`
AS `childPlantId`,`p`.`parentPlantId`
AS `parentPlantId`,`pt`.`propagationTypeName`
AS `relationshipType` FROM (`plantpropagation` `p` join `propagationtype` `pt` on(`pt`.`propagationTypeId` = `p`.`propagationTypeId`)) WHERE `p`.`isActive` = 1

