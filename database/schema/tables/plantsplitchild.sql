CREATE TABLE IF NOT EXISTS `plantsplitchild` (
  `plantSplitChildId` int(11) NOT NULL AUTO_INCREMENT,
  `plantSplitId` int(11) NOT NULL,
  `childPlantId` int(11) NOT NULL COMMENT 'New plant created from the split',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  PRIMARY KEY (`plantSplitChildId`),
  UNIQUE KEY `uxPlantSplitChild_childPlantId` (`childPlantId`),
  KEY `ixPlantSplitChild_splitId` (`plantSplitId`),
  CONSTRAINT `chkPlantSplitChildIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB  ;

