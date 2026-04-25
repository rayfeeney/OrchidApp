CREATE TABLE IF NOT EXISTS `observationtype` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `typeCode` varchar(30) NOT NULL,
  `displayName` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `isSystem` tinyint(1) NOT NULL DEFAULT 0,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  `updatedDateTime` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `ux_observationtype_typeCode` (`typeCode`)

) ENGINE=InnoDB     COMMENT='Defines subtypes of Observation records. System rows may drive application behaviour.';

