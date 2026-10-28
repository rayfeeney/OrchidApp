# Historical Linux reviewed database adoption and upgrade checks

## Status and application

The exact frozen specimen now passes the database adoption/forward-migration phase locally. Full C18 application-package, app-only and recovery acceptance is NOT complete. This ZIP supersedes OrchidApp-Historical-Linux-Preflight-changes-only.zip and includes its source changes.

Apply at the OrchidApp repository root AFTER CHAT-R01-R03 and merged CHAT-R04. The earlier preflight-only ZIP is optional; this ZIP includes/replaces that work. Review overlapping newer branch edits. Root CHANGELOG.md describes this delivery; preserve/merge any existing project changelog. No files are deleted. Do not copy the entire ChatGPT workspace, private capture or large specimen into Git.

The 23 listed repository files plus this root CHANGELOG.md are the complete delivery. There is no application/installer binary, data dump, credential file, captured Git object, fixture tarball, generated metadata SQL or build directory. The large reviewed fixture remains outside Git. No GitHub upload/remote CI run is claimed.

Run from the repository root with Python 3.9+, .NET SDK targeting net8.0, PowerShell 7+ and Docker Linux containers. First: python tests/HistoricalUpgrade.Checks/checks.py. Then: python tests/HistoricalUpgrade.Checks/preflight.py --specimen "PATH/OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz" --adopt-and-migrate. Without the last flag the original checksum refusal remains expected. See the README for details.

## Every added or modified file

- `.github/workflows/historical-linux-preflight.yml`: Manual database workflow with reviewed-adoption option, original-refusal option and bounded reports/logs.
- `.github/workflows/ci.yml`: Run the 17 pure historical verification/adoption checks in feature CI.
- `.gitignore`: Ignore historical database staging/evidence.
- `CONTRIBUTING.md`: Document commands, reviewed adoption scope and remaining boundaries.
- `RELEASE_NOTES.md`: Record actual database acceptance and incomplete package/recovery scope.
- `docs/index.md`: Link historical checks, investigation and adoption evidence.
- `docs/documentation-map.md`: Register documentation ownership for the reviewed database phase.
- `docs/testing-evidence.md`: Separate pure checks, actual fixture database acceptance and full C18 acceptance.
- `docs/code-change-backlog.md`: Update R05/R07 partial implementation and fixture-specific R10/R11 resolution.
- `docs/upgrade-checklist.md`: Document source-owner checks and absence of a live operational adoption action.
- `docs/historical-linux-upgrade.md`: Current results, original refusal evidence and remaining C18 stages.
- `docs/maintenance/historical-linux-fixture-review.md`: Bounded technical review of the exact frozen input and later acceptance boundary.
- `docs/maintenance/historical-ledger-compatibility.md`: Original findings, release artifact comparisons, owner provenance and implemented resolution.
- `tests/HistoricalUpgrade.Checks/fixture.json`: Exact frozen specimen/history/counts/runtime/archive limits.
- `tests/HistoricalUpgrade.Checks/preflight.py`: Verify/restore, reproduce original refusal, optionally adopt reviewed structure and test four actual migrations/zero-work repeat with unchanged data/history.
- `tests/HistoricalUpgrade.Checks/checks.py`: 17 unit tests including unsafe input, schema/security identity, ownership, ledger retention and partial-adoption refusal.
- `tests/HistoricalUpgrade.Checks/README.md`: Prerequisites, commands, outputs, manual workflow and exact scope.
- `tests/HistoricalUpgrade.Checks/ClientProxy/ClientProxy.csproj`: Native .NET 8 client transport executable project.
- `tests/HistoricalUpgrade.Checks/ClientProxy/Program.cs`: Restrict unchanged canonical client transport to the identity-verified isolated fixture.
- `tests/HistoricalUpgrade.Checks/schema_contract.py`: Exact 13-category schema metadata and deterministic identities without blanket normalisation.
- `tests/HistoricalUpgrade.Checks/legacy_adoption.py`: Fixture-only admission, staged marker and atomic original-ledger archival; no old row deletion or checksum rewrite.
- `tests/HistoricalUpgrade.Checks/legacy-adoption.json`: Versioned exact pre/post schema contracts, historical/current source inventories and explicitly reviewed differences.
- `docs/maintenance/historical-linux-adoption.md`: Independent structural comparison, explicitly reviewed differences and actual migration/retention evidence.

## Actual validation

- 17 verifier/adoption unit tests passed; Python compilation and both workflow actionlint syntax checks passed (optional shellcheck/pyflakes disabled). 271 local documentation links resolve.
- Independently built 87 historical schema files from captured revision 080ba9c and the current canonical schema in separate pinned isolated MariaDB servers. Reviewed all 13 metadata categories, including object definitions, columns/indexes/constraints, security/creation context, partitions and event inventory. Exact historical/final fingerprints and explicit differences are documented.
- Final real disposable acceptance: added an unreviewed view, confirmed schema admission refused it with original history unchanged, removed the owned probe and verified the exact starting schema again.
- Atomically retained the original schemaversion table as schemaversion_legacy_pi_130, preserving all 245 original IDs/names/checksums/timestamps, including the owner-identified local June test. A reviewed contract-identified baseline through 202606041820 starts active accounting. No original record or migration file was rewritten/deleted.
- The unchanged canonical runner planned/applied four real forward migrations; second apply returned zero with zero pending/applied files. Active ledger contains exactly the reviewed baseline plus four current raw hashes. Exact post-upgrade schema check passed.
- All 23 application-table data-only dump bytes and counts matched before/after. SHA-256: 6b8b8350197dc87b0a56cc145942ce162ef9596347cbb9dd4e7d49d4bb94cec6. Original audit history matched. All owned container/volume resources removed.
- Frozen input remains SHA-256 7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5. 1,073 files/798 synthetic image hashes verified. Published v1.2.0/v1.2.1/v1.3.0 artifact investigation and original failed preflight remain documented.
- Final acceptance used source immediately before a report-field naming clarification and documentation-only changes; no further SQL/contract/behavior change followed that successful database run. Final pure checks/syntax validation passed.

## Limits and remaining work

This is fixture-only adoption in a new unbound network-none Linux amd64 MariaDB container. It cannot select or update a live collection server. The ARM64 specimen application is not executed by this command. Full current package deployment, post-upgrade plant actions, app-only upgrades, failed-state recovery, real Pi/systemd/Windows acceptance, general offline operational adoption and remote CI are not claimed. No old SQL, .gitattributes, canonical runner, C# migration policy, production setting or normal startup change is included. Raw checking remains intact for forward migrations. Do not use the fixture contract as a general force/bypass/adoption mechanism for other installations.

The manual workflow defaults to reviewed database adoption and requires the future reviewed fixture release asset; missing input fails. Do not label this green database phase full C18 acceptance. Preserve all evidence and the immutable input; a failed/interrupted disposable run is discarded and restored rather than automatically repaired.
