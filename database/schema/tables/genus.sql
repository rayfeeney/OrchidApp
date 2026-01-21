DROP TABLE IF EXISTS `genus`;

CREATE TABLE `genus` (
  `genusId` int NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for genus',
  `genusName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Canonical genus name (e.g. Phalaenopsis)',
  `genusNotes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'General notes about this genus',
  `isActive` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = usable, 0 = retired or deprecated',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`genusId`),
  UNIQUE KEY `uqGenus_GenusName` (`genusName`),
  CONSTRAINT `chkGenusIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Genus information for orchid species and hybrids.';

