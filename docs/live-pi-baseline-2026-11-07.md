# Live Raspberry Pi Baseline — 7 November 2026

**Work-list item:** 4 — Record the live Pi baseline  
**Evidence status:** Complete  
**Method:** Read-only inspection of the running installation  
**Purpose:** Establish the live installation baseline before recovery backup, restoration and upgrade rehearsal.

## Hardware and operating system

- Hostname: `PiForPiHole`
- Hardware: Raspberry Pi 5 Model B Rev 1.1
- Architecture: ARM64 (`aarch64`)
- Operating system: Debian GNU/Linux 12 (bookworm)
- Kernel: `6.12.93+rpt-rpi-2712`
- RAM: approximately 15 GiB
- Storage: 32 GB-class microSD, root filesystem approximately 71% used, 7.9 GB available at inspection.

## Application and runtime

- .NET runtime: 8.0.23
- ASP.NET Core runtime: 8.0.23
- .NET SDK: 8.0.417
- Git: 2.39.5
- Repository revision: `080ba9c`
- Git description: `v1.3.0-7-g080ba9c`
- Published application: `/opt/orchidapp/publish/OrchidApp.Web.dll`
- Published DLL timestamp: 24 October 2026, 10:32 BST
- ASP.NET Core environment: `Production`
- Listening address: `http://0.0.0.0:5000`
- Application service: `orchidapp.service`

The repository revision was verified separately from the published binary. The exact binary-to-source provenance was not established and must not be assumed from the Git checkout.

## MariaDB database

- Server: MariaDB 10.11.14
- Database: `orchids`
- Base tables: 24
- Views: 16
- Stored procedures: 22
- Functions: 1
- Triggers: 2
- Total schema objects in these categories: 65
- Recorded migration history: 245 entries
- SQL migration files present: 244

The historical migration `202606031900_TestViewMigrationRunner.sql` is recorded as applied but intentionally absent from the deployed migration files. This is an owner-confirmed accepted exception, not a missing-migration defect.

Migration names were compared. Database-stored migration checksums were not independently compared against file contents.

## Configuration and services

- Active application environment: `Production`
- Published configuration sections include `AllowedHosts`, `Logging`, `MediaIngestion` and `Storage`.
- `.env` exists at `/opt/orchidapp/.env`; credential values were not inspected or recorded.
- `orchidapp.service`: enabled, active, running; user `raymond-23`; working directory `/opt/orchidapp/publish`; restart policy `on-failure`.
- `mariadb.service`: enabled, active, running.
- `orchidapp-environment-importer.service`: static, oneshot, triggered by `orchidapp-environment-importer.timer`.
- No systemd service drop-ins were reported for these services.
- No explicit MariaDB service dependency was found in the inspected OrchidApp service relationships.

Actual secret-bearing configuration values and the complete service-unit definitions were not included in the evidence.

## Scheduled operations

- Database backup: user cron, daily at 02:00.
- Environment email importer: systemd timer, observed at 06:00 and 18:00.
- Energy Monitoring timers: three co-hosted timer jobs identified.
- Standard Debian maintenance timers also present.

## Backups

- Script: `/usr/local/bin/backup_orchids.sh`
- Local staging: `/home/raymond-23/orchid_backups`
- Backup log: `/home/raymond-23/orchid_backup.log`
- Cron log: `/home/raymond-23/orchid_backup_cron.log`
- SQL backup: `mysqldump`, compressed with gzip.
- Remote encrypted database destination: `orchidcrypt:`
- Remote encrypted uploads destination: `orchiduploadscrypt:`
- Remote database retention: 14 days configured.
- Local SQL archives are removed after successful completion of the script.

Successful completion was logged daily from 1 to 7 November 2026. Remote database archives were listed for 25 October through 7 November, including the 4 November archive associated with a logged OneDrive upload error.

On 7 November, the latest remote SQL archive was 12,379,274 bytes. The encrypted media destination reported 958 objects totalling approximately 441.409 MiB.

Remote object existence was confirmed. Archive integrity, complete media equivalence and independent restoration were not tested as part of item 4.

## Principal file locations

| Purpose | Location |
|---|---|
| Repository and application | `/opt/orchidapp` |
| Published application | `/opt/orchidapp/publish` |
| Database schema and migrations | `/opt/orchidapp/database` |
| MariaDB data | `/var/lib/mysql` |
| Photo uploads | `/opt/orchidapp/uploads` |
| Environment imports | `/opt/orchidapp/imports` |
| Deployment rollback archives | `/opt/orchidapp-rollbacks` |
| Specimen directory | `/opt/orchidapp-specimens` |
| Application backup directory | `/opt/orchidapp/app/backups` |
| Database backup staging | `/home/raymond-23/orchid_backups` |
| OrchidApp systemd unit | `/etc/systemd/system/orchidapp.service` |
| Environment importer unit | `/etc/systemd/system/orchidapp-environment-importer.service` |

## Logging

The OrchidApp systemd service is configured to send standard output and standard error to the journal. No journal entries were returned for the inspected period beginning 6 November 2026. A separate application logging directory was not identified.

This does not establish a logging fault.

## Accepted limitations and next steps

- Published binary source provenance remains unverified.
- Secret-bearing configuration values were deliberately excluded.
- Historical test migration absence is accepted.
- Remote backup integrity and restore testing remain outside item 4.
- No services, schema objects, database records, configuration files or scheduled jobs were changed.

**Conclusion:** The live Raspberry Pi baseline evidence collection is complete. The installation is ready to proceed to work-list item 5, subject to documentation review. Item 5 must establish a complete, matched, independently recoverable backup before the second Pi restoration begins.