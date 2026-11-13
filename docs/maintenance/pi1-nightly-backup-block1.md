# Pi 1 nightly backup Block 1 — installed evidence, 13 November 2026

Evidence was supplied by the owner running commands in the Pi 1 terminal. The
agent did not connect to either Pi. This record does not certify Pi 2 restoration.
See the [operating contract](../user-guides/linux/nightly-multi-database-backup.md).

## Installed scope

- Named databases `orchids` and `EnergyMonitoring`, matching complete OrchidApp
  photographs/thumbnails/recovery records, external settings, EnergyMonitoring
  source/dependencies and named service/timer definitions. Logical accounts/grants
  are recovery reference only; not automatically applied to another server.
- Root-owned Python modules in `/usr/local/lib/orchidapp-backup`, protected JSON,
  MariaDB/SMTP files and root-owned rclone copy in `/etc/orchidapp`.
- Existing crypt remote, collection-isolated folder under `orchidcrypt:nightly-sets`.
  One local completed set; seven remote completed sets by configured policy.
  Seven-set remote deletion boundary has synthetic coverage, not seven live cycles.
- GMX sender orchidappdata@gmx.co.uk, received reports at bloodandsand44@gmail.com.
  Initial Microsoft-address delivery was not confirmed; GMX self-test arrived.

## Measured acceptance

First capture began 16:48:23 UTC. It returned zero, captured both databases/photos,
restarted writers and passed HTTP readiness 200. Capture/restart: 9.1 seconds;
total 438.7 seconds. Archive size 474,190,903 bytes. Minimum sampled free disk
4,396,077,056 bytes; post-run display 5.1 GB free. Completed remote read-back and
completion-record checks were recorded. Source capture and service restart timing
is not a measurement of SQL-lock duration alone.

Snapshot `orchidset-20261113T164823Z-0bf3d140e6c143f7a3e7632d9ee0b4dc`, SHA-256
`e89d93fc6230e914147da7a97c8767a052eab25c4597c7639c802fc3a64340d8`.

An inline recipient update exposed a defect: atomic JSON replacement inherited
normal umask, broadening the config mode and correctly blocking the next run.
Permissions were repaired to 600. The helper now explicitly creates JSON mode 600
before writing; its patch was transferred and SHA-256 verified. Source helper
SHA-256 at installation: `a7a1418577950ff673ef21a69658b5f54e5b7ff5b36dc4ed93f5c26a0c451ddd`.
Regression covers new/replacement JSON under umask 022; actual POSIX mode assertion
still needs the updated suite run on Linux. The root-rclone ownership issue was
resolved by a private copy, preserving the old user's config.

Second successful snapshot `orchidset-20261113T170758Z-1801173727854608a1e80fe8fa5497aa`
returned zero and delivered a success email. Listing showed exactly one archive
and its matching ready record. Free space remained 5.1 GB. Low-space failure was
injected in memory using a 100 GiB reserve; returned 1 before writer control and
delivered FAILED email. Overdue check used a separate empty state directory
`/var/backups/orchidapp-monitor-test-g9b88st6`; returned 1 and delivered OVERDUE email.
Actual backup/configuration/last-success were preserved. The separate low-space
run updated the real run-status file as a failed test; last-success still records
the second verified backup. This was expected, not evidence of a later real failure.

## Schedule and reversal

Timezone Europe/London; NTPSynchronized=yes. `systemd-analyze verify` returned 0.
Both timers enabled: `orchidapp-nightly.timer` at 02:00 local, monitor every 15
minutes. No catch-up backup started on enable. First automatic backup is due
14 November 2026 02:00 GMT. First real monitor: Result=success, ExecMainStatus=0;
next run listed 17:37:04 GMT after the 17:22:04 run. Inactive oneshot service
between runs is normal. Logrotate dry-run validated daily plus maxsize 1 MiB,
14 rotations; missing log is expected until messages exist.

Old user cron entry commented, other entries preserved. Complete saved crontab:
`/home/raymond-23/orchid-crontab-before-nightly-20261113-172127.txt`.
Old script and historical recovery sets retained. Reversal is deliberate: stop
and disable new timers, inspect any in-progress capture/service state and locks,
then restore the saved user crontab. Never enable both backup schedules together.
Source commit does not enable or change anything on either Pi.

## Validation boundaries

- New local synthetic suite: 21 passed. Original suite on Pi 1: 20 passed before
  the permission regression was added. Old-format local regression: 27 passed,
  four skips (native integration not selected, rclone unavailable, POSIX mode and
  symlink capabilities). These are not re-labelled as installed recovery tests.
- Owned Windows MariaDB native fixture passed actual two-database capture, held
  read lock blocking a competing write, manual SQL import, photo bytes/references
  and account export. Service/readiness/cloud/email were not real in that fixture.
- Real Pi manual capture, cloud read-back, readiness/restart, disk/timing and
  Gmail report acceptance were observed through the owner-run evidence above.
- Remaining: first overnight scheduled backup/received success report, reboot
  acceptance, exact live-set restore/application acceptance, Pi 2 refresh and
  restore reporting (Block 2), and hosted checks for the new source. No new-format
  application recovery is claimed. Work-list items 9/10 remain open.
