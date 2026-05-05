TYPE=TRIGGERS
triggers='CREATE DEFINER=`orchid`@`localhost` TRIGGER `trgPlantLocationHistoryBeforeInsert` BEFORE INSERT ON `plantlocationhistory` FOR EACH ROW BEGIN\n\n    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN\n\n        IF EXISTS (\n\n            SELECT 1\n\n            FROM plantlocationhistory\n\n            WHERE plantId = NEW.plantId\n\n              AND isActive = 1\n\n              AND endDateTime IS NULL\n\n        ) THEN\n\n            SIGNAL SQLSTATE \'45000\'\n\n                SET MESSAGE_TEXT = \'Invariant violation: multiple open locations for plant\';\n\n        END IF;\n\n    END IF;\n\nEND' 'CREATE DEFINER=`orchid`@`localhost` TRIGGER `trgPlantLocationHistoryBeforeUpdate` BEFORE UPDATE ON `plantlocationhistory` FOR EACH ROW BEGIN\n\n    \n    IF NEW.isActive = 1 AND NEW.endDateTime IS NULL THEN\n\n        IF EXISTS (\n\n            SELECT 1\n\n            FROM plantlocationhistory\n\n            WHERE plantId = NEW.plantId\n\n              AND isActive = 1\n\n              AND endDateTime IS NULL\n\n              AND plantLocationHistoryId <> OLD.plantLocationHistoryId\n\n        ) THEN\n\n            SIGNAL SQLSTATE \'45000\'\n\n                SET MESSAGE_TEXT = \'Invariant violation: multiple open locations for plant\';\n\n        END IF;\n\n    END IF;\n\nEND'
sql_modes=1411383296 1411383296
definers='orchid@localhost' 'orchid@localhost'
client_cs_names='utf8mb4' 'utf8mb4'
connection_cl_names='utf8mb4_unicode_ci' 'utf8mb4_unicode_ci'
db_cl_names='utf8mb4_unicode_ci' 'utf8mb4_unicode_ci'
created=1778010535611822 1778010535705036
