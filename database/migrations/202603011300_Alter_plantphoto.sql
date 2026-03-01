USE orchids;

-- Ensure no NULLs first
UPDATE plantphoto
SET updatedDateTime = createdDateTime
WHERE updatedDateTime IS NULL;

-- Then enforce consistency
ALTER TABLE plantphoto
    MODIFY updatedDateTime datetime NOT NULL
        DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP;