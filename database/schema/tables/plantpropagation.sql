CREATE TABLE IF NOT EXISTS `plantpropagation` (
  `plantPropagationId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant propagation lineage record',
  `parentPlantId` int(11) NOT NULL COMMENT 'Original plant used for propagation',
  `childPlantId` int(11) NOT NULL COMMENT 'New plant created from propagation',
  `propagationTypeId` int(11) NOT NULL COMMENT 'Propagation type: keiki, backbulb, cutting',
  `propagationDateTime` datetime NOT NULL COMMENT 'Date and time the propagation occurred',
  `propagationNotes` text DEFAULT NULL COMMENT 'Free-text notes about the propagation',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active record; 0 = logically removed (soft delete)',
  PRIMARY KEY (`plantPropagationId`),
  UNIQUE KEY `uxPlantPropagation_childPlantId` (`childPlantId`),
  CONSTRAINT `chkPlantPropagationIsActive` CHECK (`isActive` in (0,1)),
  CONSTRAINT `chkPlantPropagationDifferentPlants` CHECK (`parentPlantId` <> `childPlantId`)
) ENGINE=InnoDB  ;

