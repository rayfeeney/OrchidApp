INSERT INTO propagationtype (
    propagationTypeCode,
    propagationTypeName,
    isActive
)
SELECT
    'KEIKI',
    'Keiki',
    1
WHERE NOT EXISTS (
    SELECT 1
    FROM propagationtype
    WHERE propagationTypeCode = 'KEIKI'
);

INSERT INTO propagationtype (
    propagationTypeCode,
    propagationTypeName,
    isActive
)
SELECT
    'BACKBULB',
    'Backbulb',
    1
WHERE NOT EXISTS (
    SELECT 1
    FROM propagationtype
    WHERE propagationTypeCode = 'BACKBULB'
);

INSERT INTO propagationtype (
    propagationTypeCode,
    propagationTypeName,
    isActive
)
SELECT
    'CUTTING',
    'Cutting',
    1
WHERE NOT EXISTS (
    SELECT 1
    FROM propagationtype
    WHERE propagationTypeCode = 'CUTTING'
);