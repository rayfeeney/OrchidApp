ALTER TABLE orchids.plantsplit
  ADD COLUMN splitDateTime DATETIME NOT NULL
    COMMENT 'Date and time the split occurred';

ALTER TABLE orchids.plantsplit
  ADD COLUMN updatedDateTime DATETIME NOT NULL 
    DEFAULT CURRENT_TIMESTAMP 
    ON UPDATE CURRENT_TIMESTAMP
    COMMENT 'Last update timestamp (local time)';
