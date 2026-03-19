CREATE TABLE IF NOT EXISTS `phoneticprefix` (
  `prefixId` int NOT NULL AUTO_INCREMENT,
  `prefix` char(2) COLLATE utf8mb4_unicode_ci NOT NULL,
  `isActive` tinyint(1) NOT NULL DEFAULT '1',
  `createdDateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`prefixId`),
  UNIQUE KEY `uqPhoneticPrefixPrefix` (`prefix`),
  CONSTRAINT `chkPhoneticPrefixIsActive` CHECK ((`isActive` in (0,1)))
) ENGINE=InnoDB  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

