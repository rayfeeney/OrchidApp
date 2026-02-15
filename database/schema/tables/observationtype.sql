CREATE TABLE IF NOT EXISTS `observationtype` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `typeCode` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `displayName` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `isSystem` tinyint(1) NOT NULL DEFAULT '0',
  `isActive` tinyint(1) NOT NULL DEFAULT '1',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updatedDateTime` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `ux_observationtype_typeCode` (`typeCode`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Defines subtypes of Observation records. System rows may drive application behaviour.';

