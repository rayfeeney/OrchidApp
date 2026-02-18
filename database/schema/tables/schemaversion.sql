CREATE TABLE IF NOT EXISTS `schemaversion` (
  `versionId` int NOT NULL AUTO_INCREMENT,
  `scriptName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `checksum` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `appliedAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`versionId`),
  UNIQUE KEY `uq_scriptName` (`scriptName`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

