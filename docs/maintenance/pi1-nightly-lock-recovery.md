# Pi 1 scheduled backup lock failure — 15 November 2026

## Evidence and immediate recovery

The 02:00:20 scheduled service failed before capture with
`Another operation or a stale lock exists; inspect .paired-operation.lock`.
Its legacy owner.json identified PID 308213. The previous manual attempt began
14 November 20:01:01, stopped updating at upload/read-back, and had already
restarted writers/readiness after an 8.9-second capture. It never replaced the
last verified cloud record, still the 19:53 set. The FAILED value in an incomplete
run record is the initial conservative state, not proof that failure handling ran.

Owner process checks found no PID 308213, no children and no rclone/mariadb-dump
processes. No selected kernel OOM entry was found. The exact cause of the earlier
process termination is unknown; an SSH hangup is possible, not established.
OrchidApp and MariaDB were active. Space had fallen to 3.9 GB free, below the
previous approximately 4.67-billion-byte preflight estimate.

The owner ran a guarded cleanup which verified the exact dead owner and failed
snapshot, protected last-success.json/local verified archive, refused a failed-set
completion record, saved incident-20261115-0200.json privately, and removed only
the identified .nightly-upk_k5qq staging directory, unverified 20:01 archive and
dead legacy lock. Space returned to 4.9 GB. No cloud objects, verified backups,
live databases, uploads or credentials were removed. The generic startup email
was insufficiently specific; service stderr supplied the exact cause.

## Correction

`nightly_backup.py` now uses a kernel flock for its main operation, independent
monitor and durable SMTP outbox. The regular private .operation.flock inode is
permanent and never unlinked on release. The kernel owns liveness, so SIGKILL
cannot leave a permanently busy application lock. Existing legacy directory
locks still block until reviewed; no unsafe auto-delete/PID-reuse inference occurs.
The older generic orchid_backup.py CLI and Pi 2 restore operation-lock contract
are unchanged; consumers importing the updated SMTP helper get its kernel outbox
lock without an API change. Do not run mixed old/new copies against one root.

SIGHUP now uses the existing interrupted-operation unwind, like SIGINT/SIGTERM.
This does not make arbitrary hard-kill capture recovery automatic: abandoned
staging and writer state still require inspection. Preflight remains conservative
about space/readiness and retention never deletes unverified artifacts blindly.
Startup email includes safe BackupError text, while raw tool stderr/SQL remains
in private diagnostics. Prefer supervised systemctl starts to foreground SSH jobs.

## Validation and deployment acceptance

The existing nightly suite plus new cases checks:

- Real POSIX lock contention and same inode reused after normal release.
- A real holder killed with SIGKILL, followed by successful lock acquisition.
- A real main-process SIGHUP invoking cleanup and releasing the lock.
- Legacy lock preserved/refused and the safe cause present in startup reporting.

Linux CI and owner-run Pi 1 checks must execute the POSIX cases; Windows skips
three integration cases. The SMTP retry suite also covers the shared outbox API.
Source-only delivery contains the nightly module, unchanged generic helper,
synthetic tests and these notes; no live configuration/archives/credentials.

## Installed repair acceptance — owner confirmed

All eight CI jobs passed code 2e60940 in run 43698805573, including all Linux
process-death/hangup cases and the shared SMTP/standby consumers. Owner transferred
source-only package SHA-256
`2d17bc1908a18c9644c7cc4f46bd49c723a2397e342cb6e7e22b2709749c3de1`,
verified every file and ran all 26 cases on Pi 1 with no skips. The monitor
timer/service was stopped during replacement of only nightly_backup.py and then
resumed. Credentials/configuration/schedules stayed unchanged. Preflight passed:
5,243,285,504 bytes available versus 4,670,752,580 estimated required.

Owner started the installed orchidapp-nightly.service through systemd. It returned
exit 0, Result=success, ExecMainStatus=0 and inactive after normal oneshot completion.
Snapshot `orchidset-20261115T095115Z-969f203a1da843b0b077c8465d3ca52b`
ran 09:51:15.467481–09:58:20.230769 UTC, phase complete/result SUCCESS. Writers
restarted/readiness passed after 8.9 seconds; full duration 424.8 seconds.
Minimum sampled free space was 3,708,551,168 bytes. This code only returns success
after cloud read-back/ready verification, local/cloud retention and SMTP acceptance.
Owner separately confirmed actual SUCCESS receipt.

OrchidApp and MariaDB were active, both source timers enabled, monitor last fired
09:55 with next 10:10, and the next unchanged nightly schedule was 16 November
02:00 GMT. Check/preflight followed by a separate managed backup reused the
permanent kernel-lock file without manual removal. Managed execution and target
process-death tests resolve the diagnosed stale-lock failure; they do not establish
the original termination cause or automatically clean arbitrary hard-kill debris.
Pi 2 needs no format/credential change. PR #388 records the repair/evidence; merge
requires final-head CI. Subsequent nightly operation remains monitored normally.
