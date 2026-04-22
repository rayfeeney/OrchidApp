CREATE TABLE IF NOT EXISTS `plant` (
  `plantId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for individual plant',
  `taxonId` int(11) NOT NULL COMMENT 'Linked taxonomic identification (taxon); always populated (if unidentified at taxon, the taxon all null record is linked)',
  `plantName` varchar(100) DEFAULT NULL COMMENT 'Optional informal name',
  `acquisitionDate` datetime DEFAULT NULL COMMENT 'Start of the plant lifecycle in the system. All events must occur on or after this datetime. Set on creation (including split-created plants).',
  `acquisitionSource` varchar(150) DEFAULT NULL COMMENT 'Where the plant was obtained from',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = currently in collection, 0 = no longer present',
  `endReasonCode` varchar(30) DEFAULT NULL COMMENT 'Reason plant left collection (Died, GivenAway, Split, etc)',
  `endDate` datetime DEFAULT NULL COMMENT 'End of the plant lifecycle. No events may occur after this datetime. Set by terminal events (e.g. split, disposal).',
  `endNotes` text DEFAULT NULL COMMENT 'Free-text explanation of plant end-of-life',
  `plantNotes` text DEFAULT NULL COMMENT 'General grower notes for this plant',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `plantTag` char(8) NOT NULL COMMENT 'System-generated permanent accession identity',
  PRIMARY KEY (`plantId`),
  UNIQUE KEY `uqPlantPlantTag` (`plantTag`),
  KEY `ixPlantIsActive` (`isActive`),
  KEY `ixPlantEndReasonCode` (`endReasonCode`),
  KEY `ixPlantTaxonId` (`taxonId`),
  CONSTRAINT `chkPlantIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB   COMMENT='Individual orchid plants tracked in the collection.';

