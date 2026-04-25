CREATE TABLE IF NOT EXISTS `plantevent` (
  `plantEventId` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal identifier for plant event',
  `plantId` int(11) NOT NULL COMMENT 'Plant the event relates to',
  `eventDateTime` datetime NOT NULL COMMENT 'Date and time of event (local time)',
  `eventDetails` text DEFAULT NULL COMMENT 'Free-text description of event',
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Record creation timestamp (local time)',
  `isActive` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  `updatedDateTime` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Last update timestamp (local time)',
  `observationTypeId` int(11) NOT NULL,
  PRIMARY KEY (`plantEventId`),
  CONSTRAINT `chkPlantEventIsActive` CHECK (`isActive` in (0,1))

) ENGINE=InnoDB   COMMENT='General-purpose event log for plant care and observations.';

