# C01 and C02 - schema creation and baseline evidence

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

24 October 2026. Implementation in the local review-work/OrchidApp source copy. No live installation, production database, production grants or owner settings were changed.

## Implemented

- Replaced destructive rebuild with explicit non-overwriting creation, portable client resolution, UTF-8/collation enforcement and seven required target settings.
- Added generated schema/bootstrap.json for 87 SQL inputs through 202606041820, dependency-ordered views, required seeds and normalised checksums. Existing SQL and database/checksums/schema.json are unchanged.
- Added matching PowerShell/C# manifest validation and baseline recognition. Completion is recorded last in the existing schemaversion table; no new DDL or editing of historical migrations is needed.
- Desktop imports schema without scanning migrations, uses the configured endpoint/password for its client process, and rejects incomplete empty history. Passwords are passed via the child process environment, not command arguments.
- Fresh baseline timestamps cover earlier SQL; future changes are individually checksummed/applied once. Existing Desktop baseline/baseline and migration rows remain unchanged. A legacy marker alone is never promoted to the newest schema cut-off.
- Both PowerShell runners recognise baseline markers and the simple runner now checks recorded checksums. Broader enforcement remains C04. Fixed case-sensitive wrapper/export script references needed for these paths.
- Export honours the selected database and regenerates metadata from recorded DB state, with no migration-folder cut-off inference.

## Local validation

- Release web build succeeded with zero warnings/errors.
- Monitoring isolation regression: 163 checks passed after the startup changes (NuGet vulnerability lookup warning NU1900 remained unavailable).
- SchemaBaseline.Checks: 18 checks passed for manifest coverage/order, checksum normalisation, malformed/ambiguous/empty history, future-only selection, once-only selection, tampering, legacy compatibility, inventory drift and path traversal.
- Database.Checks.ps1: 28 checks passed on disposable Windows MariaDB 10.11.16. A temporary schema-only copy had no migration directory; creation succeeded with all seeds. All 16 views queried successfully, a plant was created through the stored procedure using seeded tag prefixes, and notes were read back. Confirmation mismatch and nonempty targets were refused without collection loss. Historical poison SQL was skipped, later SQL applied once, tampering rejected and legacy rows preserved. A deliberately invalid final seed left no completion marker; creation and migration refused that partial database on retry.
- Schema export in a separate fixture regenerated a byte-content-equivalent schema and identical manifest. The initial generator output and exporter output agree.
- Alternate developer runner in a synthetic clean Git fixture recognised the baseline, skipped historical poison SQL and applied one later migration.
- Actual staged Desktop application (not just a policy substitute) performed first use from schema with migrations absent. Home and Plants HTTP responses were 200; the database recorded one 64-character-checksum baseline marker. The initial test exposed a password omission caused by reading an already-open connection's sanitised connection string; corrected by preserving the original configured string for the client process.
- Staged Desktop upgrade with historical poison SQL plus one future SQL file applied only the future change, and its recorded checksum was verified. A subsequent restart reported the database up to date without a second backup invocation. Its backup invocation used an explicit synthetic success fixture inside the disposable staging directory; that fixture is NOT delivered and does not validate real backups.

## Limits and remaining work

No Linux MariaDB target was available (the local Docker Linux engine was unavailable). Run the supplied checks there before closing cross-platform acceptance. Native libvips photo upload/save/reopen was not validated in this environment; plant persistence and database-backed page access do not prove it. Packaged installer/hardware acceptance remains separate.

C01/C02 are implemented and locally verified, with Linux/native-photo acceptance still open. C03 owner Raspberry Pi acceptance also remains open. Next agreed implementation step is C04; do not treat pending device/platform acceptance as completed.

## Reproduce Desktop acceptance

Stage the Release application and public web assets with database/schema and the bundled Windows MariaDB client/dependencies. Omit database/migrations. Supply isolated ConnectionStrings__DefaultConnection and ConnectionStrings__OrchidDb to the same new database, ASPNETCORE_ENVIRONMENT=Desktop, a workspace ORCHIDAPP_UPLOAD_ROOT and an unused loopback URL. Start the staged DLL; verify one baseline marker and HTTP success on / and /Plants. Restart against that same isolated database to verify it remains up to date. A later-migration test must keep the backup gate; synthetic backup fixtures are acceptable only in disposable tests and are not operational recovery evidence.

## Follow-up: Linux CI executable resolution

The subsequent Linux CI run failed during schema export because Get-Command returned both /usr/bin/mariadb and /bin/mariadb. Resolve-MariaDbTool emitted both paths, which the invocation treated as one invalid command. The initial Windows validation missed duplicate PATH entries.

Resolution now selects the first application match for both normal lookup and explicit overrides. ToolResolution.Checks.ps1 reproduced the failure before the fix and passed all seven checks afterwards on Windows using two real executable fixtures on PATH. It also verifies execution from a path containing spaces, explicit override precedence and invalid override rejection. The schema-contract job now runs the same cross-platform test before schema export. Actual Linux CI export success remains dependent on rerunning CI; these local checks do not certify that full job.

No database objects, baseline cut-offs, schema checksums or migration history changed for this correction.

## Follow-up: Unix regression-test argument passing

The next Linux CI run passed the resolver checks but failed the fixture invocation assertion. The Unix branch's one-item argument array was unrolled by assignment from an if-expression into a scalar string. Splatting that scalar passed resolver-ok as individual characters, so echo returned r e s o l v e r - o k. The production resolver had already selected the correct single path; this failure was in the new test.

The fixture argument variable is now explicitly typed as string[], with an additional assertion for array type and expected argument count. Invocation failures now report the captured exit code and output. Eight tool-resolution checks passed on Windows. A separate native-process reproduction of the exact Unix argument construction returned exit 1 and spaced characters before the correction, then exit 0 and resolver-ok afterwards. No application, workflow, resolver or database changes were needed for this second correction. The full Linux CI job still needs rerunning; it was not run locally.

A subsequent supplied log still showed the old throw expression without Details, so it did not reflect this corrected test source. The reissued test now prints `Tool resolution check revision: array-arguments-v2` before running checks. Verify that label in the CI run for the commit containing the corrected file. This label identifies the source revision; it is not a claim that Linux CI has passed.
