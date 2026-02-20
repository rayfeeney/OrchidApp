ALTER TABLE orchids.plantsplit
  ADD COLUMN splitDateTime DATETIME NOT NULL
    COMMENT 'Date and time the split occurred';

ALTER TABLE orchids.plantsplit
  ADD COLUMN updatedDateTime DATETIME NOT NULL 
    DEFAULT CURRENT_TIMESTAMP 
    ON UPDATE CURRENT_TIMESTAMP
    COMMENT 'Last update timestamp (local time)';

ALTER TABLE orchids.plantsplit
	ADD COLUMN isActive tinyint(1) NOT NULL DEFAULT '1' 
		COMMENT '1 = active record; 0 = logically removed (soft delete)';
