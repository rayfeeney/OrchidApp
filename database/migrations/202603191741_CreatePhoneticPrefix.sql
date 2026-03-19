CREATE TABLE IF NOT EXISTS PhoneticPrefix (
    prefixId INT NOT NULL AUTO_INCREMENT,
    prefix CHAR(2) NOT NULL,
    isActive TINYINT(1) NOT NULL DEFAULT 1,
    createdDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (prefixId),
    UNIQUE KEY uqPhoneticPrefixPrefix (prefix),
    CONSTRAINT chkPhoneticPrefixIsActive CHECK (isActive IN (0,1))
) ENGINE=InnoDB;