DROP TABLE IF EXISTS `species`;

CREATE TABLE `species` (
  `speciesId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for species or hybrid',
  `genus` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Canonical genus name (e.g. Phalaenopsis)',
  `speciesName` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Species epithet (NULL for hybrids)',
  `hybridName` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Registered hybrid name (NULL if unnamed or species)',
  `growthCode` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Structured growth habit code',
  `growthNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'Free-text notes about growth characteristics',
  `speciesNotes` text COLLATE utf8mb4_unicode_ci COMMENT 'General notes about this species or hybrid',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = usable, 0 = retired or deprecated',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`speciesId`),
  KEY `ixSpeciesGenus` (`genus`),
  KEY `ixSpeciesIsActive` (`isActive`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Taxonomic information for orchid species and hybrids.';

