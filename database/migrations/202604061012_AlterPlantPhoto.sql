ALTER TABLE plantphoto
ADD COLUMN thumbnailFileName VARCHAR(255) NULL
AFTER fileName;