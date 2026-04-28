CREATE TABLE IF NOT EXISTS `propagationtype` (
  `propagationTypeId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for propagation type',
  `propagationTypeCode` varchar(30) NOT NULL COMMENT 'Stable system code (KEIKI, BACKBULB, CUTTING)',
  `propagationTypeName` varchar(100) NOT NULL COMMENT 'Display name',
  `isActive` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = active; 0 = inactive',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  PRIMARY KEY (`propagationTypeId`),
  UNIQUE KEY `uxPropagationType_code` (`propagationTypeCode`),
  CONSTRAINT `chkPropagationTypeIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB;

INSERT INTO propagationtype (propagationTypeCode, propagationTypeName, isActive)
VALUES
('KEIKI', 'Keiki', 1),
('BACKBULB', 'Backbulb', 1),
('CUTTING', 'Cutting', 1);