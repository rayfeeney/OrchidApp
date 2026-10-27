# C15 and C19 photo handling and recovery

Changes only: 30 modified and 25 added repository files plus this CHANGELOG.md. No deletions or moves. No private .env, credentials, collection data, owner photos or runtime binaries. Synthetic image fixtures are included for native checks. The four edited Word guides retain all 60 embedded illustrations.

## Apply to the source checkout

1. Extract over the source repository root containing OrchidApp.sln, replacing only the listed files. This follows C14 and the earlier C11-C13 changes. Review the file list below. This ZIP is source, not an installed application or installer update.
2. Stop the development app. From the repository root run the existing command:

   ```powershell
   pwsh ./scripts/DevSetup/update-database.ps1
   ```

   The repository-root .env holds the credentials. The wrapper backs up and applies pending migrations through the canonical runner. No database name or password needs to be entered again. New migration: `202610271200_PhotoTaxonTransaction.sql`. Do not bypass the pre-commit export guard or change applied history.
3. Start normally with dotnet run from src/OrchidApp.Web. Require `/health/ready` 200 and test a new plant/species photo, thumbnail and reopening. Commit normally and run CI. The hook exports schema; it never applies migrations.

## Result

New photos are rotated upright. The existing StripGpsMetadata=true default now removes GPS/private camera metadata from main and thumbnail while retaining ICC colour. Explicit false retains metadata. Alpha is white; existing photos are not rewritten. Both new JPEG files must succeed. Confirmed request rollback removes its newly generated files and database writes. Unknown commit/rollback or failed cleanup retains private recovery records and files for review rather than guessing SQL did not commit.

Liveness and readiness are separate. Readiness checks explicit database configuration/C19 contract, writable upload root, actual native save/decode, active photo/thumbnail presence and unresolved recovery records. The launcher waits for readiness. The read-only report and operator recovery procedure are in docs/photo-handling.md. Never delete recovery journals merely to force readiness.

## Windows and Linux upgrade actions

Apply the exact C19 migration through the canonical installed/operational route with a stopped-writer paired backup, then deploy the matching rebuilt application and generated schema assets. Windows needs a fully rebuilt/tested package; the launcher now waits for /health/ready. Linux must verify its installed native libraries, writable upload root and readiness 200 after service start/restore. Audit explicit MediaIngestion:StripGpsMetadata=false overrides; the default needs no configuration change. Keep .photo-recovery with SQL and uploads in recovery backups.

The full separate platform action list is docs/upgrade-checklist.md. Windows Normal backup still does not stop all writers across SQL dump and file copying; a verified ZIP is not proof of a consistent concurrent snapshot. Linux backup coordination covers configured writer units. Preserve journals after restore, stop writers and reconcile against the verified database before clearing resolved records. C18 installer safeguards and C20 release-wide evidence remain unfinished.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | .gitattributes | Pin only the new migration to LF for a stable raw checksum across platforms. |
| Modified | .github/workflows/ci.yml | Install native photo libraries for Linux HTTP checks and identify photo recovery coverage. |
| Modified | CONTRIBUTING.md | Document native policy/recovery fixtures and disposable SQL/HTTP acceptance. |
| Modified | RELEASE_NOTES.md | Describe new-photo policy, readiness and exact migration adoption. |
| Modified | database/checksums/schema.json | Official exporter checksums for the updated canonical routine. |
| Added | database/migrations/202610271200_PhotoTaxonTransaction.sql | Preserve the caller transaction when updating taxon details and replacing a photo. |
| Modified | database/schema/bootstrap.json | Official schema manifest through C19 with 87 inputs. |
| Modified | database/schema/routines/spUpdateTaxonDetails.sql | Official exported routine for fresh schema-only creation. |
| Modified | docs/architecture.md | Describe implemented photo policy, transaction compensation and readiness limits. |
| Modified | docs/code-change-backlog.md | Record C15/C19 source implementation and pending Linux/installed acceptance. |
| Modified | docs/development-setup.md | Keep ordinary dotnet run and existing .env-based migration adoption. |
| Modified | docs/documentation-map.md | Identify the photo policy and recovery documentation owner. |
| Modified | docs/index.md | Link photo policy and validation evidence. |
| Added | docs/maintenance/c15-c19-photo-handling.md | Record actual checks, migration identity, deployment implications and remaining acceptance. |
| Added | docs/photo-handling.md | Define metadata, rotation, paired writes, readiness and read-only recovery review. |
| Modified | docs/temporal-design.md | Link photo compensation to the existing request transaction boundary. |
| Modified | docs/upgrade-checklist.md | Add exact migration, policy audit, readiness and journal recovery actions for both platforms. |
| Modified | docs/user-guides/linux/02-AddAndManagePlantsInOrchidApp-LinuxPi.docx | Describe new-photo privacy, rotation and whole-batch cancellation; retain screenshots. |
| Modified | docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md | Require paired journal preservation and application readiness after restore. |
| Modified | docs/user-guides/linux/installation-upgrade.md | Check installed native/photo readiness and document repair of a missing upload root. |
| Modified | docs/user-guides/windows/01-InstallOrUpgradeOrchidAppOnWindows.docx | Explain launcher readiness checks before the app opens. |
| Modified | docs/user-guides/windows/03-AddAndManagePlantsInOrchidApp.docx | Apply the shared photo privacy, rotation and failure guidance. |
| Modified | docs/user-guides/windows/05-RecoverOrchidAppOnReplacementWindowsComputer.docx | Explain readiness after restore and preservation of recovery evidence. |
| Modified | docs/windows-backup-format.md | Clarify SQL/photo pairing, retained journals and concurrent backup limitations. |
| Modified | docs/windows-upgrade-contract.md | Add photo readiness and recovery acceptance to the installed upgrade contract. |
| Added | scripts/PhotoRecovery/review.ps1 | Report references/presence for retained generated photo paths without modifying SQL or files. |
| Modified | src/OrchidApp.Launcher/OrchidAppLauncherForm.cs | Wait for /health/ready instead of a successful Home response. |
| Modified | src/OrchidApp.Web/Pages/Plants/Events/Add.cshtml.cs | Remove incorrect local cleanup; the enclosing request batch owns generated files. |
| Modified | src/OrchidApp.Web/Program.cs | Register scoped photo coordination, taxon filter, dynamic protected uploads and health endpoints. |
| Added | src/OrchidApp.Web/Services/PhotoNativeProbe.cs | Probe actual native photo/thumbnail save and decode in isolated generated storage. |
| Modified | src/OrchidApp.Web/Services/PhotoPipeline.cs | Autorotate, honor metadata policy, preserve ICC, and require both published JPEG outputs. |
| Added | src/OrchidApp.Web/Services/PhotoWriteBatch.cs | Durably journal generated file intents and retain uncertain outcomes for operator review. |
| Added | src/OrchidApp.Web/Services/PhotoWriteCompletion.cs | Coordinate confirmed database commit/rollback with batch completion and validate the C19 contract. |
| Modified | src/OrchidApp.Web/Services/PlantWriteFilter.cs | Complete the existing locked request transaction through shared photo coordination. |
| Added | src/OrchidApp.Web/Services/ReadinessProbe.cs | Check explicit DB contract, upload write/read/delete, native processing, active files and recovery records. |
| Added | src/OrchidApp.Web/Services/TaxonWriteFilter.cs | Enclose taxon add/edit/photo replacement in a caller-preserving transaction and lock edited rows. |
| Added | src/OrchidApp.Web/Services/UploadFileProvider.cs | Serve repaired upload roots dynamically while hiding recovery records and probes. |
| Modified | tests/DevelopmentNative.Checks/DevelopmentNative.Checks.csproj | Reference the actual Web implementation and copy synthetic fixtures to check output. |
| Added | tests/DevelopmentNative.Checks/PhotoPolicyChecks.cs | Check all orientation/metadata modes, ICC, alpha and rejected inputs on the native runtime. |
| Added | tests/DevelopmentNative.Checks/PhotoRecoveryChecks.cs | Check partial pair failures, request outcomes, cleanup failures and missing dependencies. |
| Modified | tests/DevelopmentNative.Checks/Program.cs | Run the new assertions alongside the native save/reopen round trip. |
| Added | tests/DevelopmentNative.Checks/fixtures/animated.gif | Synthetic animated image used to verify rejection. |
| Added | tests/DevelopmentNative.Checks/fixtures/manifest.json | Independent expected orientation pixels/dimensions and retained ICC checksum. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-1.jpg | Synthetic image with EXIF orientation 1, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-2.jpg | Synthetic image with EXIF orientation 2, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-3.jpg | Synthetic image with EXIF orientation 3, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-4.jpg | Synthetic image with EXIF orientation 4, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-5.jpg | Synthetic image with EXIF orientation 5, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-6.jpg | Synthetic image with EXIF orientation 6, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-7.jpg | Synthetic image with EXIF orientation 7, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/orientation-8.jpg | Synthetic image with EXIF orientation 8, test GPS/XMP and ICC profile. |
| Added | tests/DevelopmentNative.Checks/fixtures/transparent.png | Synthetic alpha fixture for white-background output. |
| Modified | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Run 19 photo scenarios before C11-C14 on both upgraded and schema-only fixtures; restore old taxon routine. |
| Added | tests/LifecycleClosure.Checks/PhotoConsistency.Checks.py | Exercise actual SQL/HTTP upload rollback, readiness, private journals, report and paired archive restore. |
| Added | tests/LifecycleClosure.Checks/PreC19UpdateTaxonDetails.sql | Retain the genuine preceding routine only for the disposable upgrade fixture. |

## Validation completed

- Windows native libvips 8.18.2: 611 metadata/orientation/colour assertions and 32 file/transaction recovery assertions passed, plus the existing generated-photo/thumbnail save/decode round trip.
- Owned Windows MariaDB 10.11.16 and Release web hosts: 19 C15/C19 SQL/HTTP scenarios on each upgraded/fresh schema-only fixture plus 130 C11-C14 executions, 168 passed total. Includes actual synthetic SQL-and-upload ZIP restore, retained/private journals and a read-only reference report. The old C13 cache-aware concurrency checks remain intact.
- 44 schema creation/baseline, 53 migration and 10 child-process protocol checks passed. 18 static baseline checks and 24 Desktop migration policy scenarios passed; 248 packaged migrations validated. Launcher and SQL/HTTP Release builds passed with zero warnings/errors. Workflow validation passed with optional ShellCheck/Pyflakes disabled; changed PowerShell and Python syntax and local Markdown links checked.
- Official exporter regenerated only the canonical taxon routine, schema checksums and 87-input bootstrap through 202610271200. All 247 preceding migrations and all other existing database artifacts remain byte-identical. New migration raw SHA-256: b736d92b502c47cd30cc44d08eec89122196d2340d481a444202116cb1d81686.
- Four Word guides rendered and all 53 pages visually inspected, including individual changed pages. All 60 embedded media files unchanged. QA PDFs/PNGs are not separate deliverables.
- Full source hash comparison and ZIP path/byte checks confirm this exact file set with no deletions/moves. Existing .env development helpers, configuration, backup implementations and package versions are unchanged. No owner's .env, development/collection DB or live photos were used or modified. Only owned disposable fixtures were used; processes/databases were cleaned up and diagnostic folders retained.

## Remaining acceptance and limits

Linux CI, actual Windows installer/launcher, Linux/Pi native/service, representative older-installation and production backup/recovery acceptance remain pending. Controlled commit/rollback/native failures do not prove physical crash recovery on every runtime. The collection readiness check verifies active file existence/nonzero length; it does not decode every historical image or certify all schema drift/backup consistency. SQL and files remain separate resources. No automatic orphan deletion or historical photo rewrite is introduced. NU1900 reports unavailable NuGet vulnerability metadata; no completed vulnerability audit is claimed.

Next in the agreed order: C18, then C20.
