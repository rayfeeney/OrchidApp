# Pi 1 nightly multi-database backup — Block 1

This opt-in command leaves the old single-database repository commands unchanged.
On the owner's Pi 1, the old cron entry is now disabled and new systemd timers
are enabled. See [installed evidence](../../maintenance/pi1-nightly-backup-block1.md).
Pi 2 restore (Block 2) is not implemented; see its [implementation contract](nightly-standby-restore.md)
and recorded preparation. The new
`orchidapp-mariadb-set-v1` format is **incompatible with the old restore CLI**.
The owner agreed separate backup and restore blocks: Block 1 is scheduled after
manual backup/email acceptance; exact live-set restore/application acceptance is
pending Block 2. Do not describe recoverability as proven meanwhile; preserve the
earlier recovery archives. No migrations/authentication/grant changes are included.

## Owner-run inventory, 13 November 2026

Pi 1 has `orchids` (25 InnoDB base tables, 205.6 MiB allocated including indexes)
and `EnergyMonitoring` (10 InnoDB base tables, 2.4 MiB). Counts of 41/16 include
views. Both have no events; scheduler OFF. Uploads occupy about 445 MiB including
`.photo-recovery`. Configuration is in `/etc/orchidapp` and EnergyMonitoring's
`.env`. Three EnergyMonitoring collectors and the OrchidApp importer have timers.
Python 3.11.2, MariaDB client/dump 10.11.14, rclone 1.73.0 are installed; about
5.6 GiB is free. The user's crypt access passed. Root access, full writer/file
scope, compatible publication identity and email delivery still need checking.

## Contract

Keep `nightly_backup.py` beside unchanged `orchid_backup.py`. Root-owned code goes
in `/usr/local/lib/orchidapp-backup`; JSON/credentials are private. The example is
owner-specific, not a general installer. A stable collection UUID is appended to
the configured dedicated crypt remote directory. Old SQL/media remotes and
existing recovery archives are untouched.

Preflight creates/checks that cloud directory, confirms database existence and
allocation, hashes selected files, checks local readiness and available space.
Required free space is `4 * (source bytes + 2 * allocated database bytes) + reserve_bytes`
(default reserve 1 GiB). This is an estimate, not a guarantee. SQL expansion and
other disk users can exhaust space. Previous archives are not deleted to make
room. A half-second sampler records approximate minimum free space during a run.

Timers stop before services. One persistent global MariaDB read lock spans all
database dumps, file copies/hash checks and active OrchidApp photo/thumbnail
checks. It blocks server-wide writes. External/ad hoc writers must also be paused;
before/after hashes cannot prove an edit was not made and reverted. MariaDB stays
running. Previously active services restart before timers on capture exit,
including ordinary failure. Previously inactive units stay inactive. Local
`/health/ready` must return 200 before and after capture; this checks OrchidApp,
not collector/provider connections. Compression and cloud transfer happen after
restart. SIGINT/SIGTERM unwind; SIGKILL/power loss/repeated interruption can leave
stopped services, temporary files and stale locks. Inspect before clearing them.

Each unique archive contains `manifest.json`, `databases/<name>.sql`, `accounts.sql`
and `sources/<configured-name>`. SQL includes CREATE/USE, views, routines, triggers
and events. Accounts/grants use logical `--system=users` for private recovery
reference, including server accounts outside the selected databases. Never apply
it wholesale to Pi 2. Internal system databases are not application payloads.
Sources include photographs, hidden recovery records, external configuration,
EnergyMonitoring source/dependencies and named service/timer definitions. `.venv`
is recreated separately. Identify drop-ins and additional configuration explicitly.
Compatible OrchidApp binaries/runtime remain separately retained. Manifest records
software identity; do not assume source HEAD identifies deployed binary bytes.
OS modes/owners/ACLs are not a restore contract; configure target permissions.

Streaming local archive verification checks hashes/inventory/required photos,
without creating another extraction copy. `rclone copyto --immutable` uploads the
archive; an independent download must hash-match. Only then is a `.ready.json`
record uploaded and downloaded for verification. It contains collection UUID,
snapshot, archive/hash/size, database list and recovery-point/completion times.
Block 2 must discover only those records and independently validate the archive.
An archive alone is not a completed handoff. Hashes detect corruption, not
authenticity; trust only protected storage. Local archives contain plaintext
secrets. Configured remote type must be crypt; preserve/test keys separately.

Retention defaults to one local and seven cloud completed sets. Local pruning
requires exact generated names, correct collection/databases and matching archive
hash. A sibling `.tar.gz.keep` pins a local input outside the count. Unknown,
orphan, corrupt and pinned files stay. Remote pruning accepts only exact records
in this collection directory with matching archive presence, and requires the
current verified set before deleting. Discovery record is removed before archive;
interruption can leave orphan archives for manual review. Remote pins are not
implemented. Do not put unrelated recovery material in this managed directory.
Upload/read-back failure never prunes. Retention failure reports failure but keeps
the new cloud-verified point in `last-success.json`.

`run.json` records phase, snapshot, times, service outcome, duration and approximate
minimum free space; `last-success.json` identifies the last cloud-verified point.
Private `.tool-error-*` files may contain secrets/SQL: never share them unredacted.
The backup operation lock is conservative; stale locks are never auto-cleared.

## Email and monitoring

Sender: orchidappdata@gmx.co.uk; recipient: bloodandsand44@gmail.com. Python's standard
library uses certificate-verified TLS on port 465 or STARTTLS on 587, then login.
[GMX documents mail.gmx.com with these ports](https://support.gmx.com/pop-imap/imap/server.html).
Use the permitted SMTP/app password; test actual delivery, not just connection.

Reports go to a private durable outbox first. A successful backup with failed
email is recorded separately and is not repeated. Each message has a stable ID,
at most 12 delivery attempts, one per invocation. The 15-minute monitor retries;
exhausted messages remain for review. Ambiguous SMTP disconnects can produce
duplicates; SMTP acceptance does not prove inbox receipt. Outbox locking prevents
simultaneous sends. A killed sender may leave a stale email lock needing inspection.

Freshness is based on recovery-point age (default maximum 30 hours). No completed
point, an overdue point or a future timestamp triggers an overdue report, queued
at most daily. Monitoring uses a separate lock and works with a stuck backup lock.
It does not monitor Pi 2 or independently monitor power loss. Invalid configuration,
unreadable credentials, full disk or failed SMTP can prevent notification: inspect
journal/outbox during acceptance. Never clear records merely to force success.

Exit codes: 0 success; 1 backup/configuration/overdue failure; 2 backup succeeded
but email failed, or email-only delivery failed. Mail excludes raw tool stderr.

## Installation and acceptance procedure

1. Transfer only the reviewed package; verify SHA-256. Install code root-owned in
   the new directory, not a user-writable checkout. Do not replace the old script.
2. Run the synthetic suite on Linux first. Verify actual source scope/drop-ins,
   software identity, root's explicit rclone config access, readiness and free space.
3. Create a root-owned mode-600 copy of the existing rclone configuration at
   `/etc/orchidapp/nightly-rclone.conf`; keep the original user's file unchanged.
   Root's credential policy rejects a user-owned file even with mode 600. Preserve
   this independent refreshed credential copy and crypt keys in recovery planning.
   Create mode-600 `/etc/orchidapp/nightly.json` from the example, replacing UUID
   and software identity. Run `configure_nightly_secrets.py` interactively as root.
   It prompts invisibly, refuses existing targets, creates mode-600 MariaDB and
   GMX files and makes no account/grant/service/schedule changes. It uses existing
   account credentials over loopback TCP; diagnose a refusal without changing auth.
4. Run `check` and `email-test` below; owner must confirm receipt. Controlled email
   failure tests use a separate private config, not changes to real credentials.
5. Agree a manual capture window. Run `backup` and inspect readiness/service
   restoration, exact local/cloud verification, email, duration and disk minimum.
6. Under the agreed two-block rollout, restore that exact multi-database set on an isolated target using Block 2 or a
   separately reviewed manual procedure. Verify every database, files, settings,
   records and isolated application save/reopen. This remains pending and does not
   prevent the agreed Block 1 schedule; keep prior recovery archives. Old restore CLI cannot do this.
7. Test upload/read-back, missing files, restart failure, low space and stale-state
   notifications in disposable fixtures, never by corrupting production inputs.
8. Review provided systemd units and logrotate file. Backup timer uses host-local
   02:00, `Persistent=true` (missed runs can start on enable/boot), two-hour start
   and 180-second stop limits. Hard timeout can leave cleanup work. Agree this
   before enabling. Monitoring runs every 15 minutes. No backup auto-retry.
9. Save old crontab privately, remove only its old backup entry, then enable new
   timers. Do not run both schedules. Verify the first scheduled cycle/email.
   Reversal: stop/disable new jobs, inspect writer state/locks, restore saved cron;
   preserve all verified inputs. No timers are enabled by source preparation.

```
sudo python3 /usr/local/lib/orchidapp-backup/nightly_backup.py check --config /etc/orchidapp/nightly.json
sudo python3 /usr/local/lib/orchidapp-backup/nightly_backup.py email-test --config /etc/orchidapp/nightly.json
# Manual capture only after the preparation checks and capture window are agreed:
sudo python3 /usr/local/lib/orchidapp-backup/nightly_backup.py backup --config /etc/orchidapp/nightly.json
# Archive verification only; no restore:
sudo python3 /usr/local/lib/orchidapp-backup/nightly_backup.py verify --config /etc/orchidapp/nightly.json --archive /ABSOLUTE/EXACT_ARCHIVE.tar.gz
```

## Source checks and remaining evidence

Run `python tests/LinuxBackup.Checks/nightly_checks.py` and the old regression suite
`python tests/LinuxBackup.Checks/checks.py` from repository root. The new suite uses
synthetic SQL/service/cloud/mail adapters and temporary files. These checks do not
prove native multi-database recovery or real systemd/crypt/provider/SMTP behavior.
Linux/WSL/Docker are unavailable in this local environment. An owned Windows
MariaDB pipe-only fixture passed actual two-database capture, a blocked competing
write under the read lock, SQL import of both dumps, photo bytes/references and
account export (`nightly_native_windows.py`). Service/readiness were adapters;
this is not Linux or full application restore acceptance. The first restricted
attempt exited before readiness; the approved isolated run passed. Actual Pi
install, permissions, downtime/disk measurements, real OneDrive read-back and SMTP
receipt were subsequently exercised through owner-run commands; see the installed
evidence record. Full restore/application checks, reboot acceptance and first
scheduled backup/received email remain pending. The agent did not directly connect
to either Pi. The JSON permission regression fix passed 21 local synthetic tests;
the original 20-test suite passed on Pi 1 before that fix. No Word user workflow
changed; the authoritative Linux Markdown procedure is maintained here.
