ALTER TABLE `plantsplitchild`
  ADD CONSTRAINT `fkPlantSplitChildSplit`
  FOREIGN KEY (`plantSplitId`)
  REFERENCES `plantsplit` (`plantSplitId`)
  ON DELETE RESTRICT
  ON UPDATE RESTRICT;

