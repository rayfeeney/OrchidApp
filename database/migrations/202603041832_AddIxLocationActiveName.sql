USE orchids;

CREATE INDEX ixLocationActiveName
ON location (isActive, locationName);