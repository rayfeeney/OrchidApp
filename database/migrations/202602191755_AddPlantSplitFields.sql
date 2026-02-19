ALTER TABLE orchids.plantsplit
	ADD COLUMN isActive tinyint(1) NOT NULL DEFAULT '1' 
		COMMENT '1 = active record; 0 = logically removed (soft delete)';