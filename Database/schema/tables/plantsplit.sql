DROP TABLE IF EXISTS `plantsplit`;

CREATE TABLE `plantsplit` (
  `plantSplitId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant split lineage record',
  `parentPlantId` int NOT NULL COMMENT 'Original plant that was split',
  `childPlantId` int NOT NULL COMMENT 'New plant created from the split',
  `splitDate` date NOT NULL COMMENT 'Date the split occurred',
  `splitReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for splitting (Overgrown, Rescue, Share, etc)',
  `splitReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation of why the plant was split',
  `splitNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about the split outcome',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  PRIMARY KEY (`plantSplitId`),
  UNIQUE KEY `uqPlantSplitUniquePair` (`parentPlantId`,`childPlantId`),
  KEY `ixPlantSplitParent` (`parentPlantId`,`splitDate`),
  KEY `ixPlantSplitChild` (`childPlantId`,`splitDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

