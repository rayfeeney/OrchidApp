INSERT INTO observationtype (typeCode, displayName, description, isSystem, isActive)
SELECT 'OBS_NOTE', 'Note', 'Observation containing written notes only', 1, 1
WHERE NOT EXISTS (
    SELECT 1 FROM observationtype WHERE typeCode = 'OBS_NOTE'
);

INSERT INTO observationtype (typeCode, displayName, description, isSystem, isActive)
SELECT 'OBS_PHOTO', 'Photo', 'Observation containing one or more photos', 1, 1
WHERE NOT EXISTS (
    SELECT 1 FROM observationtype WHERE typeCode = 'OBS_PHOTO'
);

INSERT INTO observationtype (typeCode, displayName, description, isSystem, isActive)
SELECT 'OBS_FEED_GROWTH', 'Growth Feed', 'Feeding - growth fertiliser', 1, 1
WHERE NOT EXISTS (
    SELECT 1 FROM observationtype WHERE typeCode = 'OBS_FEED_GROWTH'
);

INSERT INTO observationtype (typeCode, displayName, description, isSystem, isActive)
SELECT 'OBS_FEED_BLOOM', 'Bloom Feed', 'Feeding - bloom fertiliser', 1, 1
WHERE NOT EXISTS (
    SELECT 1 FROM observationtype WHERE typeCode = 'OBS_FEED_BLOOM'
);