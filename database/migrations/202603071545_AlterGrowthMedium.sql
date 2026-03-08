USE orchids;

ALTER TABLE growthmedium
    RENAME COLUMN `createdAt` TO `createdDateTime`;

ALTER TABLE growthmedium
    RENAME COLUMN `updatedAt` TO `updatedDateTime`;