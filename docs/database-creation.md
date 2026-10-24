# Database creation and subsequent changes

A new OrchidApp environment must be created from database/schema/ alone, including its required reference seeds. Historical migration SQL must not be needed, read or executed to create the database. Migrations apply only to schema changes after that database's creation. This is the owner's required contract; current automation does not yet meet it completely.

## Creation inputs

The canonical export contains tables, constraints, views, routines, triggers and required reference seeds. Import these in dependency order into an explicitly selected empty, isolated target using utf8mb4 and utf8mb4_unicode_ci. Views must be dependency ordered, not merely alphabetically sorted. Required initial reference values include observation types, phonetic prefixes and propagation types; user collection data is not seed data.

Creation must work with database/migrations/ absent. Baseline identity and any metadata needed to decide which later changes are pending must be supplied with the schema export. Baseline bookkeeping must not depend on scanning or executing historic migration files. The baseline format/cutover mechanism is implementation work, not an operator task to invent.

A created database is not forbidden from receiving future migrations. It must reject historical changes already represented in its schema and accept only subsequent compatible changes. Keep a fresh-creation test and an existing-database upgrade test separate.

## Current implementation limits

- database/scripts/rebuild.ps1 is destructive, Windows-path-specific, requires seven MARIADB_* settings and currently sorts dependent views alphabetically. It is not a supported copy-and-run Linux or fresh-developer recipe.
- Desktop bootstrap in src/OrchidApp.Web/Program.cs imports schema but also enumerates packaged migration files to populate history. That creation dependency must be removed under the required schema-only contract.
- Apply-Migrations.ps1 is for existing, correctly baselined databases. It skips recorded filenames and does not enforce all history integrity rules. It must not be used to initialise an empty environment.
- CI assembles the schema but does not establish the complete seeded, migration-directory-independent application first run or future-upgrade baseline contract.

Track fixes as [C01, C02, C04 and C05](code-change-backlog.md). Until they are implemented and tested, a fresh environment needs a reviewed schema-only bootstrap supplied/validated by its maintainer. Do not offer migration replay or the current rebuild script as a workaround. The [developer guide](development-setup.md) and [Linux guide](user-guides/linux/installation-upgrade.md) explicitly stop at this prerequisite.

## Acceptance

With the migrations directory unavailable, create a fresh database from the exported schema and metadata, load required seeds, open database-backed pages, create a test plant and save/reopen a photo. Verify generated schema consistency. Add a later migration and prove it applies once; prove historical DDL is not replayed. Run on supported Windows and Linux MariaDB targets using isolated data.
