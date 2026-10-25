# C10 legacy migration reconciliation

The launcher now records version 2 ownership and copy inventory before writing ProgramData. Interrupted copying resumes only missing files from the same unchanged, backed-up capture; existing destination files must match the recorded inventory. Each new file is checked in separate work space and moved into place without overwriting an existing target. Unknown/changed data stops for support rather than being discarded.

After verified copy, state becomes AwaitingReadiness. Database failure, web failure or completion-write failure leaves that phase pending. A later launch retries readiness against the same target, never recopies raw database files that startup may have modified. Completion follows database-directory identity and successful web response. A matching target token and completed version 2 state establish precedence over the exact preserved source. Changed or unrelated legacy sources still stop.

State writes use flushed temporary files and same-directory atomic replacement. An operation lock serialises migration, and the launcher refuses ordinary Close during copying/readiness. Original source, captures, partial target, temporary work and safety ZIPs are retained. Existing version 1 records are not automatically adopted: copy-only completion does not prove readiness.

## Validation

All 57 combined source/recovery/reconciliation executable checks passed. New scenarios include interrupted per-file copy, missing-file resume, failed state commit after full copy, locked completion-state write with previous JSON retained, readiness failure/retry without raw recopy, source preservation, target precedence, changed/unrelated sources, changed/unknown partial files, target token mismatch/missing token, missing backup, changed capture, version 1/empty/corrupt state and residual system database files. Release launcher builds without warnings/errors.

All 69 isolated Windows MariaDB database checks passed. The suite interrupts a real raw-data copy, resumes it, exercises a native server startup failure and readiness retry, starts/queries the copied database, records completion and resolves the retained original on a subsequent launch. The existing backup/restore regressions run in the same suite. Existing Windows CI steps execute the expanded checks; GitHub Actions has not been run here. The database fixture validates database startup and state transitions, not the interactive installed launcher/browser path.

The Windows 01 installation guide is updated in this delivery. All 11 embedded media files were preserved byte-identically. Native Word PDF export and the packaged page renderer produced 12 pages; all pages were visually inspected. QA PDF/page images remain outside the source ZIP.

## Limits

No automatic rollback/deletion of partial destinations is implemented. Changed partial data, corrupt/missing ownership proof or unsupported older state requires support. The original must remain quiescent; restarting its database can change raw files and invalidate its fingerprint. Completion establishes startup readiness, not exhaustive data/device acceptance. Local generated fixtures do not replace a reviewed historical installation or real installer tests. Existing fixed packaged database credentials remain a runtime assumption; unexpected credentials stop readiness safely. The working Development .env startup flow is unchanged.
