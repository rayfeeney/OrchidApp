CREATE TABLE IF NOT EXISTS `plantsplit` (
  `plantSplitId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant split lineage record',
  `parentPlantId` int NOT NULL COMMENT 'Original plant that was split',
  `splitReasonCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Reason for splitting (Overgrown, Rescue, Share, etc)',
  `splitReasonNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text explanation of why the plant was split',
  `splitNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Additional notes about the split outcome',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `splitDateTime` datetime NOT NULL COMMENT 'Date and time the split occurred',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`plantSplitId`),
  KEY `ixPlantSplitParent` (`parentPlantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

