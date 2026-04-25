CREATE TABLE IF NOT EXISTS `genus` (
  `genusId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for genus',
  `genusName` varchar(100) NOT NULL COMMENT 'Canonical genus name (e.g. Phalaenopsis)',
  `genusNotes` text DEFAULT NULL COMMENT 'General notes about this genus',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 Indicates this genus represents the current accepted classification for assignments; 0 Indicates inactive genus remaining historically valid and must not be deleted',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`genusId`),
  UNIQUE KEY `uqGenus_GenusName` (`genusName`),
  CONSTRAINT `chkGenusIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB    COMMENT='Genus information for orchid species and hybrids.';

