CREATE TABLE orchids.plantsplitchild (
  plantSplitChildId INT NOT NULL AUTO_INCREMENT,
  plantSplitId INT NOT NULL,
  childPlantId INT NOT NULL COMMENT 'New plant created from the split',
  createdDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp (local time)',
  updatedDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp (local time)',
  isActive tinyint NOT NULL DEFAULT '1' COMMENT 'Indicates whether this record is valid for use; inactive records represent superseded or erroneous entries retained for audit purposes',
  PRIMARY KEY (plantSplitChildId),
  UNIQUE KEY uxPlantSplitChild_childPlantId (childPlantId),
  KEY ixPlantSplitChild_splitId (plantSplitId),
  CONSTRAINT fkPlantSplitChild_split
    FOREIGN KEY (plantSplitId)
    REFERENCES orchids.plantsplit (plantSplitId)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fkPlantSplitChild_plant
    FOREIGN KEY (childPlantId)
    REFERENCES orchids.plant (plantId)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
