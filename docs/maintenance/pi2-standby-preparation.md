# Pi 2 Block 2 preparation and archive validation — 13 November 2026

Status reconciled 14 November: preparation and isolated data restore passed; source
settings activation, working application acceptance and scheduling remain pending.
The full coordinator is incomplete. The owner runs all Pi commands; the agent has
not connected to a Pi.
See the [Block 2 implementation contract](../user-guides/linux/nightly-standby-restore.md).

Subsequent phase 1 development adds `standby_restore.py`, an example config,
package builder and 23 tests (22 pass locally; actual rclone crypt case requires
the installed tool and runs in Linux CI). It implements discovery/download/
validation/inert staging only and has not been deployed to Pi 2. Database restore,
application acceptance and full reporting remain pending. This development does
not retroactively convert the owner-run archive check into an automatic restore.

## Owner-reported clean baseline

- Host `pihole2`, SSH address `192.168.7.50`, account `raymond-23`, ARM64/aarch64.
- Debian 13 retained; rclone reports raspbian 13.7 (64 bit), kernel
  `6.18.50+rpt-rpi-2712`. Pi-hole remains operational and outside OrchidApp restore.
- Root filesystem: 58 GB displayed, 11 GB used, 45 GB available, 20% used.
- Python 3.13.5. PowerShell 7.6.6 retained (owner report). `dotnet` absent.
- MariaDB 11.8.6 (`11.8.6-MariaDB-0+deb13u1 from Debian`), active/enabled.
  Data directory `/var/lib/mysql/`, event scheduler OFF, lower_case_table_names=0,
  server charset utf8mb4, collation utf8mb4_general_ci. Only information_schema,
  mysql, performance_schema and sys existed at the baseline. No OrchidApp or
  EnergyMonitoring service/timer units were listed.
- Previous OrchidApp/development installation and application databases removed;
  owner explicitly states all previous Pi 2 application data is disposable.
  This does not authorize changing Pi-hole, Pi 1 or arbitrary unrelated paths.
- Chosen baseline is MariaDB 11.8.6, not a replacement with 10.11. Pi 1 runs
  10.11.14. A logical restore and application acceptance across that version
  boundary must pass; matching configuration is not proof of compatibility.

## Extra MariaDB instance identified and stopped

Package installation reported a stale user-session MariaDB process. Inspection
found PID 7312, started 7 November, user raymond-23, deleted old executable,
`--no-defaults`, data `/tmp/orchid-pi2-restore.CJrgy5QB/data`, Unix socket
`/tmp/orchid-pi2-restore.CJrgy5QB/restore.sock`, `--skip-networking`.
This was a previous temporary restore-test server, separate from the intended
systemd MariaDB service (observed PID 51094, mysql user). Owner sent SIGTERM only
to PID 7312. Subsequent process listing showed only 51094 and service remained
active. Temporary files were not deleted in this sequence. The system server was
observed listening on 0.0.0.0:3306; do not treat it as isolated merely because a
standby configuration uses loopback. Block 2 candidates require their own guarded
data directories and endpoints and must not reuse that listener accidentally.

## rclone and private cloud configuration

Debian package candidate was 1.60.1; official rclone 1.73.0 ARM64 DEB was downloaded
from `https://downloads.rclone.org/v1.73.0/` and checked against its SHA256SUMS.
Owner installed only rclone (no package removals/upgrades in that transaction).
Version reports 1.73.0, matching Pi 1. No service restarts were requested.

Pi 1's root-owned `/etc/orchidapp/nightly-rclone.conf` was copied into a temporary
mode-600 user transfer file, transferred via the owner's PC using scp -3, and
installed root:root mode 600 at `/etc/orchidapp-standby/rclone.conf` under a private
mode-700 directory. Remote names listed: onedrive, orchidcrypt, orchiduploadscrypt.
No configuration contents, provider tokens or crypt keys were pasted or committed.
Private transfer copies remain to be removed deliberately after validation.

The copied credentials retain their provider permissions; no provider-level
read-only restriction has been demonstrated. The future restore coordinator must
only list/read cloud objects and never upload, sync or prune OneDrive. Token
refresh may update Pi 2's private local rclone configuration normally.

## Exact downloaded and validated input

Encrypted directory:
`orchidcrypt:nightly-sets/55b442ba-1ee1-455b-96ba-dcf978e43683`.
Listing returned two matching archive/ready pairs for 16:48:23 and 17:07:58 UTC.
The newer exact ready record was read before downloading:

- Format `orchidapp-mariadb-set-v1`.
- Collection `55b442ba-1ee1-455b-96ba-dcf978e43683`.
- Snapshot `orchidset-20261113T170758Z-1801173727854608a1e80fe8fa5497aa`.
- SHA-256 `5b4903dda296acdc303784fc58242596ef86109c79aa3b1785968484f43c7b12`.
- Size 474,190,970 bytes. Databases orchids and EnergyMonitoring.
- Recovery point 2026-11-13T17:07:58.612331+00:00;
  cloud completion 2026-11-13T17:13:07.242409+00:00.

The archive was downloaded with copyto --immutable into root-owned mode-700
`/var/backups/orchidapp-standby`, then set mode 600. Explicit sha256sum returned OK.
Manifest inspection found 756 required active photo/thumbnail references, complete
OrchidApp uploads/settings sources, EnergyMonitoring .env/source/SQL/dependencies,
and named OrchidApp/importer/collector service/timer definitions.
Required publication identity is OrchidApp.Web.dll SHA-256
`be2812be9e85348de49a784afead57307b24e666e138e8e389baf69f5374f150`.
The matching application binaries are not themselves present in the backup.
An owner-run check on Pi 1 subsequently confirmed its deployed DLL still matches
this exact hash. Pi 1 lists Microsoft.AspNetCore.App 8.0.23 and
Microsoft.NETCore.App 8.0.23 in `/home/raymond-23/.dotnet/shared`. This establishes
source availability/runtime identity, not application installation or successful
startup on Pi 2. Runtime servicing and ARM64 native dependencies still need review.

Two existing Block 1 modules were transferred from the PC, checksum-checked and
installed root-owned mode 644 in `/usr/local/lib/orchidapp-standby`:

- nightly_backup.py:
  `a7a1418577950ff673ef21a69658b5f54e5b7ff5b36dc4ed93f5c26a0c451ddd`.
- orchid_backup.py:
  `49004275b640fe3c098def61d8d3bb5c421092bb2bd46c718bec7db07ee6876c`.

The owner invoked the existing `nightly_backup.validate` function with explicit
collection ID, database list and 20 GiB unpack limit. It printed:
`Archive inventory, file hashes and required photographs: PASSED`, and the exact
snapshot identity above. This checks each archived payload's inventory/hash,
archive member safety, nonempty database/account payloads and required photo paths.
It is not an SQL import, application test or proof of version compatibility.
At this initial check, the archive had not been extracted or its settings activated.
The subsequent packaged rehearsal is recorded below.

## Installed packaged preparation and data restore

Transferred package SHA-256:
`57be8456f002798f0f245080b89a94cb9a6b004153d6707fd2467b7daa81bd61`.
All internal file hashes passed, as did 23 staging/local-crypt checks and 10
candidate policy checks on Pi 2. Four modules were installed root-owned under
`/usr/local/lib/orchidapp-standby`. The new `orchidstandby` system account has no
login shell. `/var/lib/orchidapp-standby` is root:root mode 700;
`/var/lib/orchidapp-standby-db` is orchidstandby:orchidstandby mode 700. The private
target JSON is `/etc/orchidapp-standby/standby.json`.

Discovery selected the exact 17:07:58 snapshot above. `prepare` returned zero and
PREPARED_RESTORE_PENDING, downloading, checking and privately extracting it under
the state root's `generations/<snapshot>` directory. Source settings stayed inert.
`restore-data` returned zero and DATA_RESTORED_APPLICATION_PENDING on
`11.8.6-MariaDB-0+deb13u1 from Debian`. Base-table counts: orchids=25,
EnergyMonitoring=10. Accepted state was unchanged.

The command checked its own socket/datadir/server identity before SQL, excluded
accounts.sql, compared restored photo references/files and stopped its own child
before successful return. Independent post-run process/Pi-hole inspection has not
been supplied; no command targeted the normal service or Pi-hole. No source
settings/writers or matching publication/runtime have been activated. Do not retry
the data import into this populated generation; its state machine refuses reuse.

## First application rehearsal — blocked by view definers

Second owner-run policy package passed all 54 target checks. Token-authorized
fresh clone `206193c9b1a842faaa1e6dae7b469355` failed before view ALTER with
"Missing view definition/columns". Metadata diagnosis found the Enphase SELECT
present (2370 characters) but zero columns; the other five views returned columns.
CHECK TABLE reported absent root@192.168.7.153 and labelled the view "Corrupt";
this is an invalid-definer result, not evidence of damaged underlying data.
The displayed stored SELECT uses derived aggregation, a tariff join and named
UTC/Europe/London conversion. Source now adds the reviewed 15-column Enphase
fallback/post-check, a realistic derived-view regression and candidate-only named
timezone setup/winter-summer verification. None has been deployed on Pi 2 yet.
Both failed clones and reports remain retained; application acceptance is pending.

Hosted revision d733f98 rejected its own regression precondition: the simplified
derived fixture still returned columns, so it did not reproduce the target failure.
The fixture is being corrected to include synthetic Enphase/Tariff rows, date-hour
grouping, last-battery aggregation and the named-zone tariff-date join. The
missing-column assertion remains required. No failed CI package was handed over.
EnergyMonitoring source/schema remains owned by its separate repository; this
repository owns the shared backup/restore coordinator and disposable compatibility
fixtures only. A permanent source view change belongs in EnergyMonitoring's repo.

The closer fixture at 1ea2bfb also returned columns on Ubuntu 11.8.6. The test now
explicitly fault-injects only the first Enphase column-metadata response as empty;
all ALTER/remaining metadata/post-query checks and timezone imports remain real
MariaDB operations. It first verifies the real fixture has the expected 15 columns
and asserts the injected branch was exercised. This is boundary fault coverage,
not proof of natural reproduction of Pi 2's missing metadata. Actual target
acceptance remains pending; no failing CI package has been delivered.

Latest native run reaches timezone setup but rejects an unprotected zonefile/path
on the hosted runner. The protection remains enforced; errors now identify the
exact public path, numeric owner and mode so the environment mismatch can be
diagnosed. No source credentials or SQL are included in that diagnostic.

Hosted f00e340 identified root-owned `/usr/share/zoneinfo/Etc/UTC` mode 777.
CI preparation now sets only the two required public zonefiles to 644 on its
disposable runner and records their ancestor permissions. Runtime validation still
rejects world/group-writable files and ancestors. A policy regression verifies
mode 777 is refused before compiler/import. This changes no Pi permissions and
does not claim that Pi 2 has the same image problem.

Owner verified all package hashes and passed 23 staging, 10 data, 8 publication
and 7 application-policy checks on Pi 2. Installed helpers root-owned and created
the private application root. First invocation refused the user-owned mode-600
publication. Root-owned mode-600 copy
`/var/backups/orchidapp-standby/publication.tar.gz` resolved that preflight check.

The next rehearsal restored a new disposable database, then failed before app
launch because six EnergyMonitoring views name absent root@192.168.7.153:
vw_Tariff, vw_MonitoringDeviceLocation, vw_GoveeHourly, vw_EnphaseHourly,
vw_TapoHourly, vw_WeatherHourly. Owner-run diagnosis on that exact candidate
confirmed all orchids views/routines/triggers use the present root@localhost.
Only fresh local bootstrap accounts exist. No source accounts were imported.

Source now adds explicit energy-six-v1 mapping to a locked SELECT-only local
definer and exact failed-token retry on another new clone, retaining the failed
attempt. This has not been deployed/proved on Pi 2. No app/standby acceptance or
Pi 2 schedule exists. See the operating guide for policy, retry and CI boundaries.

## Runtime and publication installed evidence — 14 November

The owner captured the matching Pi 1 publication without source changes, transferred
it privately and verified it on Pi 2. Archive size 246377067 bytes; SHA-256
`3622b8dd41e8c99f8a0c6ae60b44999434e55398d5321b520954e9aef1aaf274`.
PUBLICATION_VERIFIED reported the expected backup DLL fingerprint, aarch64 and
net8.0. No source settings were activated.

Owner installed libvips42t64 8.16.1-1+deb13u2 after a simulation showed nine new
packages and no removals/upgrades. Official ARM64 ASP.NET runtime archive 8.0.34
passed its Microsoft release-metadata SHA-512 check and was extracted privately
to `/opt/orchidapp-standby/dotnet-8.0.34`. Both Microsoft.AspNetCore.App and
Microsoft.NETCore.App report 8.0.34. Pi-hole and the system MariaDB remained active.
.NET 8 is now out of support; target application compatibility is still unproven.

New `standby_application.py` is a source-only disposable readiness/page/photo/restart
rehearsal. Its own application/SQL/uploads clone does not alter the pristine data
candidate. Local policy results and hosted checks must be reviewed before packaging
for Pi 2. No application probe, CRUD acceptance, promotion, restore email or timer
has been run or accepted on Pi 2 yet.

## Matching publication helper — source prepared 14 November

Pi 1's deployed DLL matches the backup; both runtime families are 8.0.23 as recorded
above. New `standby_publication.py` source checks source ARM64/.NET 8 metadata,
expected DLL hash, source/copy inventories, space and complete archive integrity,
then publishes a private matching software archive without overwriting an input
or modifying source files/services. Eight local synthetic tests passed after this
PC granted temporary-hard-link access; the restricted attempt was not passing.
Actual capture/transfer and new Linux hosted checks remain pending. No live
publication, configuration, photographs, SQL or credentials are committed.

## Pending work and acceptance

Hosted native data-stage evidence: run 43514710945 at `7c090cb` passed synthetic
10.11.14-to-11.8 candidate import, both database data, routines/views/triggers,
events off, photo references/bytes, excluded accounts.sql, retained partial-DDL
state, retry refusal and preservation of a synthetic earlier acceptance marker.
This is not a real installed application restore. In that run, all 23 staging/
real local-crypt tests passed. Ten data-policy adapter tests passed locally but
failed on Linux because the adapter mocked the UID inconsistently with actual
file ownership. The test correction uses the real Linux UID; production permission
checks and candidate code are unchanged. Corrected head `14faccb` passed all eight
jobs in run 43515352028. Publication tests are a new change needing their own result.

1. Discovery, bounded download, validation, staging and guarded candidate data
   import have source/CI and installed evidence above. Reboot/interruption
   acceptance on Pi 2 remains pending.
2. Provision the matching application/runtime and explicit target-only credentials,
   settings, permissions and definer/grant strategy; never activate captured Pi 1
   endpoints, jobs or accounts.sql automatically.
3. Initial restore of both databases on the owned isolated 11.8 candidate passed.
   Preserve any future
   accepted standby until replacement is accepted; disposable initial state does
   not justify destructive refresh of a later working standby.
4. Verify database objects/data, photo bytes, readiness and application workflows;
   test writes must use a disposable validation clone and not enter accepted data.
5. Implement atomic acceptance state, recovery after interruption, target-only
   service activation, retention of the previous accepted generation, and email/
   overdue reports tied to snapshot identity.
6. Package/deploy the reviewed source; owner-run full rehearsal including failures,
   email receipt, peak space, reboot and first scheduled refresh. Takeover remains
   deliberate and separate. No Block 2 timer is enabled at this stage.
