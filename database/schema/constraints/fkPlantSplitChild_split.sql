ALTER TABLE `orchids`.`plantsplitchild`
  ADD CONSTRAINT `fkPlantSplitChild_split`
  FOREIGN KEY (`plantSplitId`)
  REFERENCES `orchids`.`plantsplit` (`plantSplitId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

