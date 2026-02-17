ALTER TABLE orchids.plant
  MODIFY acquisitionDate DATETIME NULL COMMENT 'Date plant was acquired or created by split';

ALTER TABLE orchids.plant
  MODIFY endDate DATETIME NULL COMMENT 'Date plant left collection or was removed by split';
