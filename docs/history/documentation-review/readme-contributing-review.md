# README and CONTRIBUTING joint review

Reviewed: 24 October 2026. Baseline: supplied OrchidApp-clean.zip.

## Assessment

The pair is not yet sufficient for a developer unfamiliar with the project to configure a clean machine and reach a working application reliably. CONTRIBUTING gives useful, largely accurate guidance about database ownership, hook behaviour, local checks and CI limitations. README provides extensive operational background but contradicts that guidance about migration enforcement and gives an invalid setup command.

This is a review, not a rewrite. README.md and CONTRIBUTING.md are unchanged. Referenced guides were checked for existence, and the architecture migration heading was checked for its anchor; their full content review is deferred. Findings below are based on static inspection of the supplied source and scripts, not a successful installation or database execution.

## Findings in priority order

### 1. High: README's only developer setup command points to a missing file

README.md, Development Workflow (line 537), instructs `pwsh scripts/setup.ps1`. That file does not exist. The actual file is `scripts/DevSetup/setup.ps1`, correctly referenced by CONTRIBUTING.

Correction: make README's developer entry point a clickable link to CONTRIBUTING, or use the real command and clearly state its limited purpose. The setup script checks tools and legacy credential variables and configures Git hooks; it does not install dependencies, create a database, configure the web application or launch it.

### 2. High: There is no complete first-run development procedure

CONTRIBUTING.md, Prepare a development checkout (lines 20–70), moves from tool installation to hooks and an already reachable database. Application validation (line 180 onward) gives build and check-project commands but no application launch command or expected URL.

Missing instructions include obtaining/opening the checkout, preparing an isolated database from the current schema with required reference seeds, choosing a development account and permissions, configuring the application's connection string, selecting a writable upload location, running the web application, and confirming a successful database-backed page and photo upload.

The actual application setting is `ConnectionStrings:OrchidDb`, which can be provided as `ConnectionStrings__OrchidDb`. Setting script variables `MARIADB_*` does not configure this connection string. `Storage:UploadRoot` is separate too. Development settings currently contain machine-specific defaults: database port 3307 and upload root `C:\orchidapp\uploads`; the documented exporter/runner default is 3306. Consequently, the application and hook can target different databases unless explicitly aligned. Configuration files also contain password fields, so the documented approach must distinguish local overrides from committed shared settings without copying credentials into the guide.

A candidate source-run command, after prerequisites have been validated, is:

```powershell
dotnet run --project src/OrchidApp.Web/OrchidApp.Web.csproj --launch-profile http
```

That profile sets Development and listens at `http://localhost:5285`; it does not open a browser automatically. The Development startup path does not execute the Desktop-only database bootstrap. Document explicit database preparation rather than implying that running the app creates its schema. A repository-root `.env` file is not automatically loaded by this web startup or by the documented migration/export scripts; the rebuild script has its own loader.

### 3. High: Database bootstrap must be resolved before documenting a reliable setup

The repository contains `database/scripts/rebuild.ps1`, but it is not currently a safe basis for a claimed working onboarding recipe without validation/correction. It drops and recreates the configured database, requires seven `MARIADB_*` settings, uses a hard-coded Windows MariaDB 10.11 executable, and applies views alphabetically.

`venvironmentdailyperiodsummary.sql` references `venvironmentreadingperiod`, which sorts later. The CI workflow explicitly handles these views in dependency order; rebuild.ps1 does not. This is a confirmed ordering mismatch in the scripts, with execution failure inferred from the view dependency rather than reproduced here.

The rebuild also does not populate migration-history baseline rows. Applying all historical migrations to a current-schema rebuild can therefore replay changes already represented in that schema. README says not to mix fresh rebuild and migration mechanisms, while CONTRIBUTING does not explain the supported transition from a fresh development database to applying future migrations. Desktop bootstrap has separate history-initialisation logic.

Correction: establish and validate one supported fresh-development bootstrap and migration-baseline procedure, then document it. Explain destructive scope and require an isolated development target. Do not simply insert the existing rebuild command as an unconditional setup step.

### 4. High: README overstates migration and drift protection

README.md, Migration System (lines 295–315), claims checksum enforcement and prevention of out-of-order execution, duplicate timestamps, modified historical migrations and schema drift before execution. Its Guarantees section also says schema drift cannot occur silently.

CONTRIBUTING.md, Current migration enforcement limits (lines 119–129), correctly explains that the documented `Apply-Migrations.ps1` sorts filenames, skips previously recorded filenames and records checksums for new migrations, but does not compare skipped-file checksums or enforce timestamp format, uniqueness or chronology. It does not perform a pre-migration schema export/drift check. Desktop startup does compare recorded migration checksums, and other developer scripts have different checks. These paths must not be described as one uniformly enforced mechanism.

Correction: align README with the precise CONTRIBUTING description, link to the existing architecture comparison, and distinguish project rules from automated guarantees. CI schema rebuild/export comparison is not historical migration replay or universal runtime drift protection.

### 5. Medium: Native image-processing and launcher development prerequisites are absent

The web project references NetVips, and PhotoPipeline uses its native image operations. The clean archive intentionally omits downloaded runtimes. The Windows restore script restores libvips, and the launcher explicitly prepends its binary directory to the child web process PATH. An ordinary source `dotnet run` does not execute that launcher setup.

CONTRIBUTING does not explain restoring/providing libvips for source development, configuring native-library discovery, or checking a real photo upload. A passing managed build or feature check does not prove this workflow works.

It also does not distinguish direct web development from Windows launcher/installer development. The launcher targets `net8.0-windows` and Windows Forms and consumes published web/runtime assets. Add a short route selector: web/database work, Windows launcher/installer work, and Linux validation. Link to detailed platform procedures rather than duplicating them.

### 6. Medium: The validation inventory omits the greenhouse check project

CONTRIBUTING lists four executable check projects and describes CI as not running those four. The repository also contains `tests/GreenhouseCharts.Checks/GreenhouseCharts.Checks.csproj`, whose Program.cs includes optional live database behaviour via `GREENHOUSE_TEST_CONNECTION`.

Correction: add this project to the change-to-check mapping, explain its optional modes and database prerequisites after reviewing them, and describe CI as not running the executable feature checks. Retain the existing distinction between isolated checks, live database validation and actual platform/restore testing.

### 7. Medium: README repeats operational material and hides developer navigation

README is approximately 650 lines. Windows upgrade rules are repeated across Current Status, Deployment Model and Windows upgrades; backup and recovery paths recur too. Architecture and migration claims are repeated in introductory guarantees. Many document pointers are fenced text rather than clickable links, including CONTRIBUTING.

Correction: keep a compact product overview, platform summary, screenshots if wanted, install/documentation links, a visible developer entry point, and security/licence summaries. Put detailed operating procedures in the existing docs hierarchy. Keep CONTRIBUTING responsible for the contributor workflow and link outward for authoritative contracts. Avoid creating another competing setup guide unless the workflow needs a dedicated home under docs/.

## Reference verification

All concrete document targets explicitly named or linked by the two files exist:

| Target | Result |
| --- | --- |
| docs/index.md | Exists |
| docs/architecture.md | Exists |
| docs/architecture.md#implemented-migration-paths | File and matching heading exist |
| docs/temporal-design.md | Exists |
| docs/windows-upgrade-contract.md | Exists |
| docs/navigation.md | Exists |
| docs/rich-notes.md | Exists |
| docs/user-guides/linux/installation-upgrade.md | Exists |
| docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md | Exists |
| CONTRIBUTING.md | Exists |
| THIRD_PARTY_NOTICES.md | Exists |
| LICENSE | Exists |

The four README screenshot files exist, including the two repeated in HTML image tags. Referenced user-guide directories, shared Razor directory, CI workflow, actual setup/export/migration scripts and four listed check projects exist. `scripts/setup.ps1` does not exist. `YYYYMMDDHHMM_Name.sql` and `<platform>` are explanatory placeholders, not broken targets. Existence is not a finding that a linked guide is accurate or appropriate.

The clean ZIP contains no root AGENTS.md or .env.example. The latter was intentionally omitted by the archive command, so its absence here does not establish that it is absent from the original checkout. Review did not treat document instructions as authorisation to run setup, hooks, database changes or deployment commands.

## Next document review

Review docs/index.md first for navigation and document ownership. Then review architecture.md and temporal-design.md for contracts and migration/setup implications, followed by windows-upgrade-contract.md. Review navigation.md and rich-notes.md for contribution guidance. Review Linux installation-upgrade.md and the MariaDB backup/restore runbook together for operational consistency. Check platform-guide entries exposed by the index during that review.

Before calling onboarding complete, validate the revised instructions on a fresh isolated Windows development environment: prepare the schema and seeds, align app/script credentials and endpoint, run the web app, open a database-backed page, upload/reopen a photo, run the relevant checks, and confirm schema export/hook behaviour in a real Git checkout. Validate database behaviour on Linux as required by project policy. None of these execution checks were performed in this document review.
