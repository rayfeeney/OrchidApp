-- Run manually as a MariaDB administrator on the hosting server.
-- Existing OrchidApp local accounts only; SELECT on the existing solar table.
GRANT SELECT ON EnergyMonitoring.EnphaseInterval
TO 'orchidapp'@'localhost', 'orchidapp'@'127.0.0.1';
