# Reviewed historical Pi database adoption

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

Status, 28 October 2026: the exact sanitised specimen has passed reviewed database adoption and four real forward migrations locally; a second invocation applied nothing. This resolves the historical-ledger blocker for this fixture's database checks. It does not establish live-Pi, installed-package, app-only or recovery acceptance.

## Independent structure investigation

The actual specimen SQL was restored unchanged into pinned MariaDB 10.11.14. A separate isolated server was independently built from 87 schema files at captured source revision `080ba9c377fc22b781640272d7d32ecc3ae46a42`, applying table/constraint/routine/view/trigger/seed stages and resolving view dependencies. No old migration replay, development `.env`, live database, captured Git hooks/config or release executable was used.

Thirteen metadata categories cover the database charset/collation; 24 base tables; all table/view columns; complete index definitions; foreign keys and referential rules; checks; 16 view definitions and security/creation metadata; 23 routine bodies, parameters, security and SQL modes; two triggers; partitions and event inventory (no scheduled events). Auto-increment counters, cardinality, data values and creation times are excluded from schema identity; data and history are checked separately. Definers are included explicitly, not ignored.

The final `vplantlifecyclehistory` definition and metadata match the independently built historical reference exactly. All table structures, foreign keys/rules and checks match. Differences were reviewed explicitly:

- Three nonunique FK-supporting indexes use existing `ix...` names instead of reference `fk...` names; columns/order/type and FK behavior match.
- Seven views, nineteen routines and two triggers retain utf8mb3/general_ci creation context instead of the reference rebuild's explicit utf8mb4/unicode_ci session. This is retained historical metadata, not a claim of uniform Unicode configuration.
- `vplantrepotstatus` says `From acquisition` instead of `FROM acquisition`; two output columns have differing charset/collation metadata. The expected fixture pins these exact differences; no new collation repair is inferred or applied here.
- `spPropagatePlant` and `spSplitPlant` have one additional whitespace-only line each.

The exact accepted schema SHA-256 is `1db8365341bc8f9e05b2d08b44b5e651259103a13eee1ba2866cb0f5171ca1b0`. It is checked as exact metadata, with category hashes for diagnosis. New objects, index renames, altered routine bodies, security definers or collation changes fail; none is accepted merely as an allegedly harmless variant.

## Historical accounting decision

Published v1.2.1/v1.3.0 artifacts recover 26 old matching February payloads. The original February collation payload remains unknown, but its resulting view was subsequently replaced and the final view is independently verified. The owner identifies June's test migration as uncontrolled Pi work without a recoverable file. See [provenance investigation](historical-ledger-compatibility.md).

The controlled route retains the complete old ledger as an audit table and starts active upgrade accounting from the verified historical structure through `202606041820`. The marker checksum identifies the complete versioned review contract, not a falsely relabelled old file. No old SQL/checksum is rewritten, and no migration policy is relaxed. The June test entry has no active planning role but remains visible in preserved evidence.

This is implemented only inside a new isolated specimen restore. Fixture identity, all original row counts, original history digest and complete exact schema must match first. Previous/partial adoption tables fail. A replacement ledger is staged, populated with the existing recognised baseline marker, and atomically exchanged with the original using one multi-table RENAME. Original version IDs, script names, checksums and applied timestamps are verified unchanged in `schemaversion_legacy_pi_130`. The active marker plus four new migration records is verified separately.

The immutable input SQL supplies the database recovery input for this disposable experiment. This is not a live operational recovery design: no collection installation is contacted or modified. A future live adoption command must have its own stopped-app/consistent recovery-set and interruption/account/permissions acceptance before use.

## Actual upgrade evidence

The genuine unchanged `Apply-Migrations.ps1` and native client transport planned and applied:

1. `202610261200_AtomicManualPlantClosure.sql`
2. `202610261800_EndedPlantReadOnly.sql`
3. `202610262000_StructuralTransactions.sql`
4. `202610271200_PhotoTaxonTransaction.sql`

All first-run commands returned zero; a second apply returned zero with pending zero and no applied files. The active ledger contains exactly the contract baseline plus these four current raw file hashes. All 245 archived original records match. All 23 application-table row counts and deterministic data-only dump bytes are unchanged; before/after SHA-256 is `6b8b8350197dc87b0a56cc145942ce162ef9596347cbb9dd4e7d49d4bb94cec6`.

A second independent server was built from the current canonical schema. Resulting upgraded routine bodies/structure agree except for explicitly pinned historical context differences, eight recreated routines' fixture TCP-account definer (`root@%` versus socket-reference `root@localhost`), and a blank line in `spSetHeroPhoto`. Security types/definitions are compared; arbitrary definer differences are not ignored. The exact post-upgrade application-schema identity is `56675363e3ece25fbdc21c03722d15f0a6eecdc7c0ffa069c86f6a14cbc07800`. Ledger tables have separate exact retention/marker checks. This account behavior is scoped to the pinned disposable image, not a production definer prescription.

The final check also creates a fixture-only unreviewed view and proves adoption rejects it with original history unchanged, then removes that probe and repeats the real acceptance. Seventeen unit checks cover archive verification, schema/security exactness, ownership, ledger preservation, wrong history/scope and partial-adoption refusal. Native proxy compilation, workflow syntax and local documentation links are checked with delivery. Owned databases/volumes are removed on completion.

## Remaining boundaries

No old applied SQL or runner/Desktop policy change, new production migration, `.gitattributes` rewrite, live Pi update or fixture publication is included. Raw-byte checking continues for every forward migration; archived historical byte discrepancies no longer participate in active planning after this verified rollover. Other old installations, fresh legacy ledgers, Windows checkouts/releases and production accounts are not automatically covered by this fixture-specific contract.

This database-stage evidence is followed by [actual ARM64 package/action/app-only/recovery checks](historical-linux-application-recovery.md). Real Pi/systemd/provider/browser and Windows installed acceptance remain separate. A successful database phase must not be labelled full upgrade acceptance. See [commands](../../tests/HistoricalUpgrade.Checks/README.md) and [remaining stages](../historical-linux-upgrade.md).
