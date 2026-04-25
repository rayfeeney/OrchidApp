CREATE TABLE IF NOT EXISTS `phoneticprefix` (
  `prefixId` int(11) NOT NULL AUTO_INCREMENT,
  `prefix` char(2) NOT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT 1,
  `createdDateTime` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`prefixId`),
  UNIQUE KEY `uqPhoneticPrefixPrefix` (`prefix`),
  CONSTRAINT `chkPhoneticPrefixIsActive` CHECK (`isActive` in (0,1))
) ENGINE=InnoDB   ;

