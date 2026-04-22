CREATE TABLE IF NOT EXISTS `plantsplit` (
  `plantSplitId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant split lineage record',
  `parentPlantId` int(11) NOT NULL COMMENT 'Original plant that was split',
  `splitReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason for splitting (Overgrown, Rescue, Share, etc)',
  `splitReasonNotes` text DEFAULT NULL COMMENT 'Free-text explanation of why the plant was split',
  `splitNotes` text DEFAULT NULL COMMENT 'Additional notes about the split outcome',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `splitDateTime` datetime NOT NULL COMMENT 'Date and time the split occurred',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active record; 0 = logically removed (soft delete)',
  PRIMARY KEY (`plantSplitId`),
  UNIQUE KEY `uxPlantSplit_parentPlantId` (`parentPlantId`),
  KEY `ixPlantSplitParent` (`parentPlantId`),
  CONSTRAINT `chkPlantSplitIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB  ;

