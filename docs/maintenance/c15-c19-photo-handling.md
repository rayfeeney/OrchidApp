# C15 and C19 photo handling evidence

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

C15 implements the existing metadata setting and orientation policy. C19 adds photo request compensation, durable recovery records and database/files/native readiness. [Photo handling and recovery](../photo-handling.md) owns the operational procedure; the [upgrade checklist](../upgrade-checklist.md) contains separate Windows/Linux adoption actions.

## Implementation

PhotoPipeline materializes autorotated pixels once before writing a JPEG main image and thumbnail. With `MediaIngestion:StripGpsMetadata=true` (the unchanged default), it removes private metadata from both while retaining the ICC profile. False explicitly retains metadata. Alpha is flattened on white. Both temporary outputs must finish and publish successfully; a failure cleans only the generated attempt paths. Existing collection photos are not rewritten.

Plant writes retain the C13 parent lock and database transaction. Taxon add/edit now use a request transaction as well. The new immutable migration `202610271200_PhotoTaxonTransaction.sql` changes `spUpdateTaxonDetails` to use its own transaction or a caller-preserving savepoint. Its SHA-256 is `b736d92b502c47cd30cc44d08eec89122196d2340d481a444202116cb1d81686`. The C19 taxon filter requires the migration's exact ledger entry or a validated fresh baseline at/after `202610271200` before invoking the routine. Pending markers fail that contract.

The official exporter regenerated the routine, schema checksums and 87-input bootstrap manifest through `202610271200`. All 247 prior migration files remain byte-identical. The pre-C19 routine is retained only as a disposable upgrade-test fixture. No data backfill is required.

PhotoWriteBatch durably records generated file intents before publication. Confirmed request rollback cleans new files and their journal. Successful commit removes only the journal. Uncertain commit/rollback, unfinished requests and cleanup errors retain the files/record; no automatic orphan deletion guesses whether SQL committed. Private recovery records are excluded from static serving. The read-only PowerShell report checks current active and inactive metadata references without changing files or SQL.

Readiness checks explicitly configured database access and C19 contract, actual upload write/read/delete, native save/decode, active main/thumbnail presence and unresolved recovery records. Liveness remains separate. The launcher waits for readiness before opening the browser. Dynamic upload serving allows a missing configured root to be repaired without process restart.

## Validation completed on Windows

| Check | Result and scope |
| --- | --- |
| Native metadata/orientation/colour | 611 assertions passed with libvips 8.18.2: all eight EXIF orientations, both metadata modes, both outputs, independent expected corners/dimensions, normalized orientation, GPS/XMP, exact ICC bytes, alpha, invalid image and animated GIF |
| Native file/transaction recovery | 32 assertions passed: late second-file publish failure, validation/handler failure, success, uncertain commit/rollback, failed cleanup retaining evidence and other owned-file cleanup, native-dependency failure and missing explicit DB configuration |
| Actual SQL/HTTP | 19 new scenarios on each upgraded and schema-only fresh fixture, plus 130 C11–C14 executions: 168 passed in total against owned MariaDB 10.11.16 instances and actual Release web hosts |
| Paired recovery | Each new suite creates a synthetic SQL dump plus uploads ZIP including a retained journal, restores to a generated isolated DB/root, checks 503 until the known fixture outcome is resolved, then checks readiness and a missing/restored thumbnail |
| Static schema policy | 18 baseline checks passed |
| Database regressions | 44 creation/baseline checks, 53 migration checks and 10 child-process protocol checks passed on another owned disposable server |
| Migration policy | 24 Desktop policy scenarios passed with 248 packaged migrations |
| Launcher | Release build passed with zero warnings/errors |
| Word guides | Four guides rendered: 17 Windows plant pages, 17 Linux plant pages, 12 Windows installation pages and 7 Windows recovery pages. All 53 pages inspected; changed pages checked individually. All 60 embedded media files retain their original hashes |

The 19 SQL/HTTP scenarios cover both plant photo entry points, whole-batch cancellation, actual injected database failures, taxon add/edit/replacement rollback and successful pairs, prior-photo retention, caller-owned SQL success/failure, blocked storage, missing files, old/pending migration state, missing database, missing/repaired root, private journals, read-only reports and paired archive restore. The existing closure, ended-plant, structural concurrency and history-order scenarios remain in the same runner. Markers are `c13-lock-cache-v3`, `c14-event-type-v1` and `c15-c19-photo-v1`.

Fixtures contain synthetic EXIF/GPS/XMP and generated coloured pixels, not owner photographs or credentials. Corner expectations come from Pillow EXIF normalization independently of the application saver. ICC bytes are checked after native JPEG save. Native dependency absence is injected through the native probe interface; commit/rollback uncertainty uses a controlled transaction adapter. These tests do not simulate a universal physical power loss or prove all native runtime versions.

The successful native command emitted NU1900 because NuGet vulnerability metadata was unavailable. This is not a completed vulnerability audit. The Release SQL/HTTP fixture build completed without warnings/errors.

## Acceptance still required

Run CI on the actual revision, including Linux native policy and SQL/HTTP checks. Validate Linux/Pi native libraries, service account access and real service start/restore. Rebuild/package Windows and test the actual launcher/installer with a representative older isolated installation. Source builds do not certify those environments.

Readiness checks current active references for presence/nonzero length, not decoding every historical photo or certifying complete schema/backup integrity. SQL and files remain separate resources. Windows Normal backup still does not stop all writers across SQL dump and file copy; Linux backup coordination covers only configured units. Preserve copied journals after restore and review them with stopped writers. The synthetic paired archive checks do not certify the production backup scripts, remote provider, systemd, installer or physical recovery. C18 and C20 remain separate work.


## Later historical ARM64 acceptance: empty photo batches

The package/application checks exposed a clean-root no-photo commit creating a false recovery record, then blocking photo upload. Empty Track/Committed/RolledBack now avoid journal I/O. Five new assertions bring the native pair/transaction count to 37; all 611 metadata/orientation/colour checks and all 37 recovery checks passed locally on Windows libvips 8.18.2. The corrected current ARM64 package passed the 17 selected plant actions including photo plus note. Genuine uncertain commit/rollback and cleanup records remain protected. No SQL/settings/Word user-flow change is introduced. See [current package/recovery evidence and actual limits](historical-linux-application-recovery.md).
