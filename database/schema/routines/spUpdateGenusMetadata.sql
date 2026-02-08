DELIMITER //
CREATE PROCEDURE `spUpdateGenusMetadata`(
  IN p_genusId INT,
  IN p_genusNotes TEXT,
  IN p_isActive TINYINT
)
BEGIN
  UPDATE orchids.genus
  SET
    genusNotes  = p_genusNotes,
    isActive    = p_isActive
  WHERE genusId = p_genusId;
END
//
DELIMITER ;

