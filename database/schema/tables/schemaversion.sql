CREATE TABLE IF NOT EXISTS `schemaversion` (
  `versionId` int(11) NOT NULL AUTO_INCREMENT,
  `scriptName` varchar(255) NOT NULL,
  `checksum` char(64) NOT NULL,
  `appliedAt` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`versionId`),
  UNIQUE KEY `uq_scriptName` (`scriptName`)
) ENGINE=InnoDB   ;

