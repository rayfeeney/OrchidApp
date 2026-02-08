CREATE PROCEDURE `spUpdateGenusMetadata`(\n  IN p_genusId INT,\n  IN p_genusNotes TEXT,\n  IN p_isActive TINYINT\n)\nBEGIN\n  UPDATE orchids.genus\n  SET\n    genusNotes  = p_genusNotes,\n    isActive    = p_isActive\n  WHERE genusId = p_genusId;\nEND	utf8mb4	utf8mb4_0900_ai_ci	utf8mb4_unicode_ci

