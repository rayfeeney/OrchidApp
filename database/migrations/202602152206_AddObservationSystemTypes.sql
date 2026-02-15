-- Ensure OBS_NOTE exists
INSERT INTO orchids.observationtype
    (typeCode, displayName, description, isSystem, isActive)
SELECT
    'OBS_NOTE',
    'Note',
    'Observation containing written notes only',
    1,
    1
WHERE NOT EXISTS (
    SELECT 1
    FROM observationtype
    WHERE typeCode = 'OBS_NOTE'
);

-- Ensure OBS_PHOTO exists
INSERT INTO orchids.observationtype
    (typeCode, displayName, description, isSystem, isActive)
SELECT
    'OBS_PHOTO',
    'Photo',
    'Observation containing one or more photos',
    1,
    1
WHERE NOT EXISTS (
    SELECT 1
    FROM observationtype
    WHERE typeCode = 'OBS_PHOTO'
);
