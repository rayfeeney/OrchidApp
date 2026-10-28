# Historical Linux upgrade acceptance

Status: specimen verification, exact reviewed structure/adoption and **actual database forward migration passed locally**, including a second apply with no work. CHAT-R10/R11 are addressed for this exact disposable fixture through audited ledger rollover; broad live adoption is not implemented. Full application-package, app-only and recovery acceptance remains incomplete. Earlier application workflows ran on the old specimen, not as post-upgrade tests in this workflow. See [reviewed adoption and evidence](maintenance/historical-linux-adoption.md).

The frozen specimen is `OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz`, SHA-256 `7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5`. Its 1.3.0 application metadata and observed checkout `v1.3.0-7-g080ba9c` are recorded separately; the binary's exact source revision is not established. The specimen contains a real historical schema/history and sanitised representative records/files, not a database rebuilt by replaying migrations.

## Implemented repository checks

[HistoricalUpgrade.Checks](../tests/HistoricalUpgrade.Checks/README.md) pins the asset, rejects wrong/private archives, verifies member safety/checksums and synthetic-file inventory, restores only into a newly owned network-isolated container and calls the actual canonical PowerShell `-PlanOnly` runner through a restricted native Docker client proxy. The runner, applied SQL files and frozen input remain untouched. Default mode confirms read-only history/counts. Explicit reviewed mode preserves the original ledger in an audit table, records the verified baseline and tests actual forward migration with exact retention/data/schema checks. Both modes clean only owned Docker resources.

The feature CI job runs 17 verifier/adoption unit checks. The manually dispatched `historical-linux-preflight.yml` downloads the pinned asset from a reviewed fixture release and defaults to `--adopt-and-migrate`, retaining reports/logs on failure. Its `reviewed_adoption=false` option reproduces the original read-only refusal. It is not wired to pretend that missing input, rejected history or an untested upgrade is successful. There are no live database endpoint/credential parameters and no development `.env` load.

The preflight database is Linux amd64 MariaDB 10.11.14, matching SQL version but not duplicating the complete Pi OS/application environment. `applicationExecuted=false` remains explicit. `migrationApplicationAttempted` is true only when actual forward migration starts in reviewed adoption mode; full package/recovery acceptance remains explicitly not performed.

## Original read-only result (before reviewed adoption)

On 28 October 2026, Windows AMD64 with Python 3, .NET SDK 9.0.315, PowerShell 7 and Docker Linux containers:

- All ten verifier/policy/isolation unit tests passed, including traversal, links, duplicate members, resource caps, hash/settings mismatches, exposure/ownership checks and transport-versus-policy result classification. Test temporary files are repository-local; an initial restricted-system-temp access error was resolved in the harness, not presented as a fixture/app defect.
- The exact 94,612,484-byte asset was verified; all 1,073 inner files and 798 synthetic image hashes matched.
- The actual historical export restored successfully. All expected base-table counts and the 245-row history digest matched the fixture manifest.
- The genuine canonical `Apply-Migrations.ps1 -PlanOnly` returned nonzero for an applied-checksum mismatch. The report was **blocked**, not passed; history and all row counts remained unchanged. No migrations or app upgrade ran. The container/anonymous volume were removed after ownership checks.
- The current extracted Windows source has 242 existing-file raw mismatches and one missing applied file. LF/BOM diagnostics still leave 27 existing-file mismatches plus that missing file. Comparison against the captured Pi's own files confirms those 28 underlying incompatibilities; current-vs-captured available SQL differs only in byte formatting after diagnostic normalisation. Nothing was normalised or rewritten for application.

The subsequent [reviewed adoption evidence](maintenance/historical-linux-adoption.md) records the implemented resolution and successful real database migration. The original refusal remains reproducible without the explicit flag. See [CHAT-R10/R11 investigation](maintenance/historical-ledger-compatibility.md). Native proxy compilation and both workflow syntax checks are included with delivery. The source mirror has no Git revision; no remote CI run or fixture publication is claimed.

## Publication and the next stages

[Technical publication review](maintenance/historical-linux-fixture-review.md) covers the exact frozen bytes and retained data. The private capture is never uploaded. The large asset and sidecar checksum remain outside Git; only the manifest, checks, scripts, workflow and documentation belong in source. The archive's older internal README is preserved; supplemental review/acceptance records describe later checks.

The reviewed database starting point is now verified for this exact fixture. The controlled rollover archives every original ledger record unchanged, records the reviewed schema contract as a recognised historical baseline, then applies only the four actual forward migrations. Do not substitute this narrow fixture evidence for a live adoption tool or complete packaged upgrade acceptance. No arbitrary baseline, checksum variant or migration rewrite is accepted.

The remaining C18 implementation must:

1. Preserve a consistent recovery set of old application/database/photos/configuration before mutation.
2. Retain the completed database-phase checks: exact starting schema/history, audited rollover, all four canonical forward migrations, unchanged application-data hashes, exact final structure and zero work on the second apply. Integrate these with the package/application phases.
3. Deploy the actual current Linux package or supported publish/deployment process, preserving representative records, references and photo bytes.
4. Run the expanded observation quick actions/note/photo, movement, flowering, repotting and two-child-split tests against the **upgraded** application; confirm the new validation explanations, restart persistence and unchanged preserved baseline data before test mutations.
5. Test app-only upgrades, failed DDL/incomplete state and restoration of a working compatible app/data/files/configuration set. Do not remove pending markers to force a retry or claim DDL rollback.
6. Retain exact package/runtime identities and actual results. Real Pi/systemd/OS-account and browser acceptance remain separate; Windows requires its own reviewed baseline and installer scenarios.

The initial C05 current-schema creation/later-migration fixture is not replaced or relabelled as older-installation acceptance. This stage adds no production setting, migration, package format or normal startup change. Existing [Windows/Linux upgrade actions](upgrade-checklist.md) still apply.
