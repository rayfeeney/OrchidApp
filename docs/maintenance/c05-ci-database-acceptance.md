# C05 CI database acceptance

## Scope and behavior

The owner agreed to test a database created from the current schema, followed by a later migration. Testing upgrades from actual older releases is a separate future task requiring a reviewed historical schema fixture or sanitised backup. No older-installation fixture is supplied or claimed here.

The previous schema job used independent shell loops with hard-coded view ordering, omitted reference seeds and never recorded the creator's baseline marker. CI now runs the production rebuild.ps1 command from a temporary stage containing database/scripts and database/schema but no database/migrations directory. The disposable MariaDB service starts without an application database; the creator chooses the explicit charset/collation, imports the manifest and seeds and records completion last. Service health checks already gate startup, so the old shell readiness loop that could fall through after repeated failures is removed.

Creation, upgrade tests and drift detection have separate purposes/targets:

- The canonical CI database is created using the supported schema-only path and remains free of synthetic future migrations or collection records. The original exporter/drift step follows, comparing exported schema/checksums/manifest with the committed artifacts.
- SchemaBaseline.Checks/Database.Checks.ps1 uses a generated orchids_contract_<guid> target, staged production scripts/schema and separately supplied synthetic migration files. It verifies the transition from freshly baselined current schema to an existing installation with representative records, then to one later schema change.
- Existing C04 migration policy/database tests remain in the workflow, covering broader rejection, concurrency and failed-DDL behavior. The C# SchemaBaseline.Checks policy test is added to the build job.

No production SQL, schema, checksum, manifest or migration-runner behavior changes are included. Negative fixtures modify only temporary copies. Existing synthetic legacy-history assertions remain bookkeeping compatibility checks; they do not represent a restored historical installation.

## Expanded disposable database checks

The 44-check suite covers:

- Production creator staged without any migration directory; mismatched confirmation and populated-target refusal.
- Missing required observation seed file and missing bootstrap manifest rejected before a database is created, with meaningful error messages.
- A dependent view deliberately placed before its dependency in a temporary manifest; import fails and leaves no completion marker.
- Required active observation/propagation codes, active phonetic prefixes, plant creation through stored procedures, generated plant tag and saved notes readback; all 16 canonical views query successfully.
- Exact baseline timestamp/manifest checksum, baseline-only initial history and utf8mb4_unicode_ci collation.
- PlanOnly makes no future schema change and leaves history/plant rows intact. A later synthetic migration applies once over two executions, records its raw-file checksum once, preserves the original plant/notes/baseline and leaves no pending marker. Schema-covered poison SQL is never replayed/recorded.
- Applied SQL tampering is rejected. The existing synthetic legacy baseline/checksum preservation assertions remain intact.
- Intentionally invalid late seed SQL leaves empty/incomplete history, blocks creation retry and blocks migration against incomplete state.

The suite reuses C04's child-process JSON protocol for original exception messages and exit codes. It does not search formatted stderr, avoiding the previous Linux error-wrapping failure. Native fixture queries ignore option files, use TCP/UTF-8 and have a bounded connection timeout. Generated test databases are dropped in finally; the small unique fixture directory remains for diagnosis. Environment values changed by the test are restored.

## Actual local validation

On isolated Windows x64 with MariaDB 10.11.16, PowerShell 7 and the installed .NET SDK 9.0.315/.NET 8 runtimes:

- All 44 database creation/baseline checks passed.
- All 18 C# baseline policy checks passed.
- The new CI creation block was extracted from the workflow and executed against a generated database in a disposable source/Git stage. The canonical export then passed git diff --exit-code -w --ignore-blank-lines against the staged canonical artifacts, with no drift.
- actionlint 1.7.7 workflow validation passed (ShellCheck/Pyflakes integrations disabled). PowerShell syntax parsing passed for the modified suite. Documentation link and source artifact integrity checks accompany the delivery.

The source mirror is not itself a Git checkout. The local drift comparison used an isolated Git index; no source commit or local hook-use claim is made for this change. No live collection was used, no historical migration SQL was replayed, and generated database/server test resources were cleaned up.

## Remaining acceptance and next work

The modified GitHub Actions workflow has not been executed here; its Ubuntu/MariaDB run still requires confirmation. Local Windows tests do not establish Linux filesystem case behavior. The C16 Windows/Linux native steps remain in CI and still need their own passing run confirmed. Device/installer, historical-version upgrades, representative real backup recovery and broader feature checks are outside this acceptance scope.

After C05 review/CI confirmation, the agreed next step is C06+C07: bind legacy safety backup to the detected source and restore settings from the format written by backup. See [database creation](../database-creation.md), [contribution checks](../../CONTRIBUTING.md) and [the backlog](../code-change-backlog.md).
