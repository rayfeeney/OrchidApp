CREATE TABLE IF NOT EXISTS `plantsplitchild` (
  `plantSplitChildId` int NOT NULL AUTO_INCREMENT,
  `plantSplitId` int NOT NULL,
  `childPlantId` int NOT NULL COMMENT 'New plant created from the split',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint NOT NULL DEFAULT '1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  PRIMARY KEY (`plantSplitChildId`),
  UNIQUE KEY `uxPlantSplitChild_childPlantId` (`childPlantId`),
  KEY `ixPlantSplitChild_splitId` (`plantSplitId`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

