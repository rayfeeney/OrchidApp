# Pi 2 manual takeover and isolated rehearsal

The nightly process accepts a stopped copy of both databases and OrchidApp media.
It does not automatically take over Pi 1's role. This runbook provides private
OrchidApp access using that restored database server; it does not install source
services, expose MariaDB over TCP, enable EnergyMonitoring collectors or change
Pi-hole/DNS/nginx. Both databases remain available in the same owned Unix-socket
server. Activating scheduled external feeds or public routing is a separate
operational decision: the backup/restore contract intentionally keeps them off.

All Pi commands below are run by the owner. Use the current reviewed source-only
package and keep Pi 1's normal backup running during the isolated rehearsal.

## Test without altering the accepted standby

1. On Pi 2, obtain the exact current snapshot:

   ```bash
   sudo python3 - <<'PY'
   import json
   from pathlib import Path
   print(json.loads(Path('/var/lib/orchidapp-standby/last-accepted.json').read_text())['record']['snapshot'])
   PY
   ```

2. Pause only the refresh timer, then start a separate disposable copy, replacing
   SNAPSHOT with that value. Leave the independent monitor enabled:

   ```bash
   sudo systemctl stop orchidapp-standby.timer
   sudo python3 /usr/local/lib/orchidapp-standby/standby_takeover.py rehearse \
     --config /etc/orchidapp-standby/standby.json \
     --email-config /etc/orchidapp-standby/email.json \
     --snapshot SNAPSHOT
   ```

   The helper validates the accepted pointer, checks the archive, creates a new
   isolated database and private publication/uploads workspace, and provisions
   only the existing target-specific accounts/view policy. It starts on
   `127.0.0.1:5010`, checks readiness/home and prints REHEARSAL_READY. No app
   credentials are printed. The accepted pointer/data/uploads are not the write
   target. The restore lock prevents refresh/retention during this session; the
   independent freshness monitor can still run. If a refresh is already active,
   let it finish before starting the rehearsal. Finish the rehearsal promptly.

3. In a second Windows PowerShell window, open a private SSH tunnel:

   ```powershell
   ssh -N -o ExitOnForwardFailure=yes -L 5010:127.0.0.1:5010 raymond-23@192.168.7.50
   ```

   Keep both windows open. Browse to `http://127.0.0.1:5010`. A browser on Pi 2
   can use the same address directly. The service does not bind to a public/LAN
   interface; no firewall, DNS or Pi-hole change is required.

4. On this disposable copy, create a clearly labelled test plant or edit a test
   record's notes; save, navigate away and reopen it. Upload a test photograph;
   reopen the full image and thumbnail. Confirm that both record and image are
   present. Existing production-looking records here are copies, not Pi 1 data.
   Do not enter new real collection work into a rehearsal.

5. Press Ctrl+C in the Pi 2 rehearsal window. The helper stops the app, restarts
   it, verifies readiness/home and all active photo/thumbnail bytes after the
   writes, and stops both owned processes. It records REHEARSAL_STOPPED with
   `business_data_changed=true`, `upload_files_changed=true`, two application
   starts, the post-write media count and `accepted_pointer_unchanged=true`.
   The browser save/reopen observation is owner evidence; database/file changes
   alone do not prove every user workflow. No changes observed means the write
   rehearsal is not yet complete. Failure retains its private report/files.

6. Close the Windows tunnel with Ctrl+C. Clean only the completed disposable
   rehearsal (same SNAPSHOT), preserving a small report:

   ```bash
   sudo python3 /usr/local/lib/orchidapp-standby/standby_takeover.py cleanup-rehearsal \
     --config /etc/orchidapp-standby/standby.json \
     --email-config /etc/orchidapp-standby/email.json \
     --snapshot SNAPSHOT
   ```

   This preflights exact owned paths and stopped state, excludes the accepted
   runtime/workspace and retains `takeover-rehearsal-last.json`. Failed or partial
   rehearsals require review; there is no broad delete or blind overwrite.
   After a completed rehearsal/cleanup, resume the existing refresh timer:

   ```bash
   sudo systemctl start orchidapp-standby.timer
   systemctl list-timers --all --no-pager --full | grep orchidapp-standby
   ```

## Activate during an actual Pi 1 outage

Do not run this section just to test the nightly backup. Rehearsal above leaves
the live collection alone. For an actual manual takeover:

1. **Fence Pi 1.** Confirm it is powered off or otherwise cannot run application,
   importer or collector writers. An SSH failure alone does not prove this.
   Keep it fenced while Pi 2 accepts real work. Review the accepted recovery
   point: changes made after that source backup are not magically present.
2. On Pi 2, stop refresh/monitor timers and any in-progress oneshot cleanly:

   ```bash
   sudo systemctl disable --now orchidapp-standby.timer orchidapp-standby-monitor.timer
   sudo systemctl stop orchidapp-standby.service orchidapp-standby-monitor.service
   ```

   Inspect failed/pending state before proceeding. Never delete a restore lock
   just to bypass an operation that may still own database/application processes.
3. Get the current snapshot as above, then start the accepted runtime directly:

   ```bash
   sudo python3 /usr/local/lib/orchidapp-standby/standby_takeover.py activate \
     --config /etc/orchidapp-standby/standby.json \
     --email-config /etc/orchidapp-standby/email.json \
     --snapshot SNAPSHOT --pi1-fenced
   ```

   The acknowledgement is an operator assertion, not remote fencing performed by
   this script. On first activation the helper verifies accepted files and business
   data, writes `active-takeover.json` before any user work, and starts only the
   owned MariaDB/application on loopback. Keep the terminal session open and use
   the same SSH tunnel. Both restored databases are in this server; collectors,
   importer, SQL events and public database access remain off.

   Refresh refuses to proceed while the durable takeover marker exists, even
   after a reboot or app shutdown. This protects new Pi 2 writes against an old
   Pi 1/OneDrive restore. Ctrl+C stops the app/database but deliberately keeps the
   marker. To resume the same active snapshot after a stopped session, use the
   same activate command and fencing acknowledgement. Failed ownership or stale
   process checks require review, not deletion of pid/socket files.

4. Keep the recovery archive and preserve new Pi 2 database/uploads changes
   off-device before switching back. **Never restart both writer sets or remove
   the marker to overwrite unreturned Pi 2 work.** Live failback requires a paired
   export of Pi 2 data/media, reconciliation onto the chosen primary, verification,
   and a fresh source backup before normal standby refresh resumes. This helper
   does not automate that reconciliation or claim collectors have been migrated.

## Release an activation that made no changes

After stopping the foreground app/database and confirming Pi 1 is the primary,
the guarded release can clear the marker only if all business-table counts and
checksums and all uploads/publication still match accepted evidence:

```bash
sudo python3 /usr/local/lib/orchidapp-standby/standby_takeover.py release-unchanged \
  --config /etc/orchidapp-standby/standby.json \
  --email-config /etc/orchidapp-standby/email.json \
  --snapshot SNAPSHOT --pi1-primary
```

Any new data or photo changes refuse release. Do not force this check to pass.
On an unchanged successful release, re-enable the two existing timers and verify
their next run/status. This is a narrow safe return path, not a live-data merge.

See [nightly restore](nightly-standby-restore.md) for automation, retention and
reporting, and [installed evidence](../../maintenance/pi2-standby-preparation.md)
for which machine checks have actually passed.
