UPDATE plantphoto
SET fileName = SUBSTRING_INDEX(filePath, '/', -1);