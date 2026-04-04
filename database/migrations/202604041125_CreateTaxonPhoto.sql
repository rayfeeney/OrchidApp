-- Create taxonphoto table

CREATE TABLE taxonphoto (
    taxonPhotoId INT NOT NULL AUTO_INCREMENT,
    taxonId INT NOT NULL,

    fileName VARCHAR(255) NOT NULL,
    thumbnailFileName VARCHAR(255) NOT NULL,
    mimeType VARCHAR(100) NOT NULL,

    isPrimary TINYINT(1) NOT NULL DEFAULT 1,
    isActive TINYINT(1) NOT NULL DEFAULT 1,

    createdDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedDateTime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (taxonPhotoId),

    CONSTRAINT fk_taxonphoto_taxon
        FOREIGN KEY (taxonId) REFERENCES taxon(taxonId)
);