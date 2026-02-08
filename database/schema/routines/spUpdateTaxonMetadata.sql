DELIMITER //
CREATE PROCEDURE `spUpdateTaxonMetadata`(
  IN p_taxonId INT,
  IN p_taxonNotes TEXT,
  IN p_growthNotes TEXT,
  IN p_growthCode VARCHAR(30),
  IN p_isActive TINYINT
)
BEGIN
  UPDATE orchids.taxon
  SET
    taxonNotes  = p_taxonNotes,
    growthNotes = p_growthNotes,
    growthCode  = p_growthCode,
    isActive    = p_isActive
  WHERE taxonId = p_taxonId;
END
//
DELIMITER ;

