# C08 Windows restore recovery

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

Restore now preserves a validated local copy of the selected ZIP and requires a verified safety backup before replacing the collection. Safety archives and recovery journals live outside routine backup retention. A persisted pending marker prevents normal launcher startup, migrations and normal backups after destructive interruption. Recovery explicitly chooses retained input or the original safety backup; partial state is never promoted to a new safety copy.

The launcher keeps Restore available after failure, reports a stopped web app accurately and protects recorded recovery inputs from subsequent fixed-name cloud overwrite. Completed journals remain so that protection survives restart. The maintained procedure and support commands are in the [archive contract](../windows-backup-format.md#failure-and-acceptance-boundaries).

## Validation

The Release launcher build passed with zero warnings/errors. All 23 source/recovery policy checks passed, including persistent pending state, protected cloud destinations after restart, preflight failures without a safety ZIP and unreadable history. All 28 PowerShell archive/journal checks passed under both PowerShell 7 and Windows PowerShell 5.1. The 14 existing development startup checks also passed; C08 does not change web startup or private .env handling.

All 59 Windows MariaDB 10.11 database checks passed. The suite exercises real SQL failure, post-import missing photo, locked upload/settings replacement failures, safety-copy failure, retained-input and original-safety recovery, an active prior importer guard, tool-owned database shutdown and subsequent database restart. Existing Windows CI steps run the expanded suites; GitHub Actions has not been run here.

Windows guides 04 and 05 are updated in the same delivery. All five embedded images in each guide were preserved byte-identically. Native Word PDF export and the packaged page renderer produced six and seven pages; all 13 pages were visually inspected. QA PDFs/PNGs are not shipped in the source ZIP. Screenshots continue to illustrate the existing launcher buttons; the text describes the new safety/recovery behaviour.

## Limits

No automatic or atomic rollback across SQL and files is claimed. Recovery requires readable retained inputs, usable runtime/database credentials, sufficient space and working permissions. Do not delete pending records to force startup. Preserve operation folders and seek support if explicit recovery cannot complete. Close other OrchidApp instances and avoid concurrent data changes. Local fixture tests do not prove actual installer, historical release or interactive installed-machine behaviour. GitHub Actions and installed-machine acceptance remain pending.
