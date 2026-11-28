# OrchidApp Automated Testing and MariaDB 11.8 Programme

## Programme control

- Agreed baseline date: 24 November 2026.
- Programme owner: OrchidApp project owner.
- Status: In progress.
- Scope: Automated testing, MariaDB 11.8 re-engineering and release acceptance.
- Additional financial expenditure: GBP 0.

This document is the authoritative source for the scope, sequence,
decisions, progress and completion criteria of this programme.

Do not extend the programme or introduce additional requirements without
explicit owner approval. Existing repository development, architecture,
database, documentation and release rules remain applicable.

## 1. Objectives

Establish repeatable automated Windows and Linux acceptance testing
against the current OrchidApp version before commencing the MariaDB 11.8
re-engineering.

Use the established baseline to identify regressions introduced by the
database, dependency, packaging and deployment changes.

Retain the automated testing framework for subsequent OrchidApp releases.

Windows receives greater testing emphasis because of its packaged
installer, launcher, bundled MariaDB and native dependencies. Both
Windows and Linux remain mandatory release acceptance platforms.

## 2. Fixed programme of work

| Ref | Activity | Status |
| --- | --- | --- |
| 01 | Install MariaDB 11.8 on Windows DEV PC | Complete |
| 02 | Upgrade Pi 1 to Debian 13 and MariaDB 11.8 | Complete |
| 03 | Enable and verify Windows Sandbox | Complete |
| 04 | Establish isolated Linux testing environments | Complete |
| 05 | Review existing automated tests and specimen backups | Complete |
| 06 | Implement shared application functional testing | Complete |
| 07 | Implement Windows-specific automated testing | Complete |
| 08 | Implement Linux-specific automated testing | Complete |
| 09 | Establish and approve Windows and Linux testing baselines | Complete |
| 10 | Re-engineer OrchidApp for MariaDB 11.8 | Pending |
| 11 | Repeat automated testing against the new version | Pending |
| 12 | Validate database migration and application upgrades | Pending |
| 13 | Create the new application release | Pending |
| 14 | Validate the final Windows and Linux releases | Pending |

The 14 programme references are fixed. Do not add, remove, renumber
or silently redefine activities without owner approval.

Complete and verify each activity before proceeding to the next.

Permitted status values are Pending, In progress, Blocked and Complete.

Record completion evidence alongside the relevant activity or through
a link to an existing authoritative evidence record.

## 3. Technical decisions

| Area | Decision |
| --- | --- |
| Windows acceptance environment | Windows Sandbox |
| Paid Windows virtual machine | Not required |
| Linux acceptance environment | Two isolated Debian x64 Hyper-V virtual machines on the existing Windows 11 Pro DEV PC |
| Linux virtualisation | Microsoft Hyper-V; two independent Generation 2 VMs with Secure Boot using MicrosoftUEFICertificateAuthority |
| Current database baseline | MariaDB 10.11 |
| Target database | MariaDB 11.8 |
| Application framework | .NET 8 |
| Windows test data | Existing Windows specimen backup |
| Linux test data | Existing Linux specimen backup |
| Browser automation | Playwright |
| Windows system automation | PowerShell |
| Source control | Existing OrchidApp GitHub repository |
| Development environment | Windows DEV PC |
| Production Raspberry Pis | No destructive testing |
| Additional financial expenditure | GBP 0 |
| Release version | Decide following re-engineering |

Confirm the exact current release, database versions, installer,
source commit and specimen identities during the existing test review.
Do not assume that the latest source and current published release
are identical.

Retain the exact baseline release artifacts and identify their checksums.

The established Linux baseline is Debian 12.15 with MariaDB 10.11.19.
The established Linux target is Debian 13.8 with MariaDB 11.8.9.
The environment details and verification evidence are recorded under
Activity 04 below.

An x64 Linux virtual machine does not replace ARM64 Raspberry Pi
acceptance. Record architecture-specific validation limits explicitly.

Use existing GitHub CI facilities where appropriate. Review existing
automation before introducing additional CI workflows or dependencies.

### Activity 04 - Establish isolated Linux testing environments

**Status: Complete.** The two environments were established and verified
on 25 November 2026. This completes environment establishment only; it
does not establish an OrchidApp application or automated testing baseline.

#### Approved Hyper-V configuration

The environments use the existing Windows 11 Pro DEV PC with Microsoft
Hyper-V enabled and verified. Each is an independent Generation 2 x64
Linux virtual machine with four virtual processors, fixed 4 GiB RAM and
a dynamically expanding 80 GiB virtual hard disk. Secure Boot is enabled
using `MicrosoftUEFICertificateAuthority`. Both use the existing Hyper-V
Default Switch for NAT networking and the standard Hyper-V VM and virtual
disk storage locations. Additional financial expenditure was GBP 0.

The Debian netinst media was obtained from the official Debian source and
its SHA256 checksum was compared. Independent ISO signature verification
was not performed. Both machines received a minimal server installation
with SSH server and standard system utilities; no graphical desktop is
installed.

#### Verified environment configuration

| Component | Baseline environment | Target environment |
| --- | --- | --- |
| VM name | `OrchidApp-Debian12` | `OrchidApp-Debian13` |
| Hostname | `orchidapp-debian12` | `orchidapp-debian13` |
| Operating system | Debian 12.15 | Debian 13.8 |
| Architecture | x86_64 | x86_64 |
| Kernel | 6.1.0-56-amd64 | 6.12.118+deb13-amd64 |
| MariaDB Server | 10.11.19 | 11.8.9 |
| MariaDB Client | 10.11.19 | 11.8.9 |
| .NET SDK | 8.0.428 | 8.0.428 |
| .NET Runtime | 8.0.34 | 8.0.34 |
| ASP.NET Core Runtime | 8.0.34 | 8.0.34 |
| PowerShell | 7.6.10 | 7.7.0 |
| Git | 2.39.5 | 2.47.3 |
| libvips | 8.14.1 | 8.16.1 |
| Python | 3.11.2 | 3.13.5 |
| rclone | 1.60.1-DEV | 1.60.1-DEV |
| rsync | 3.5.0 | 3.5.0 |
| tar | 1.34 | 1.35 |
| gzip | 1.12 | 1.13 |
| curl | 7.88.1 | 8.14.1 |

MariaDB and native Linux dependencies were installed from the official
Debian repositories. .NET 8 and PowerShell were installed from the
Microsoft repository appropriate to each Debian version. The recorded
native dependency installation commands were:

Debian 12:

```sh
sudo apt install -y git curl libvips42 libvips-tools libheif1 rclone
```

Debian 13:

```sh
sudo apt install -y git curl libvips42t64 libvips-tools libheif1 rclone
```

Both environments:

```sh
sudo apt install -y mariadb-server mariadb-client
sudo apt install -y dotnet-sdk-8.0 powershell
```

Both MariaDB installations have this persistent configuration in
`/etc/mysql/mariadb.conf.d/99-orchidapp.cnf`:

```ini
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

The MariaDB services were restarted and the effective settings verified.
Both servers listen on `127.0.0.1:3306` and contain only their system
databases. The Microsoft `dotnet-host` package is version 11.0.0 on both
machines; it is the shared launcher, not an additional application
runtime or SDK. The installed application SDK and shared runtimes remain
exclusively .NET 8.

#### Verification evidence

Completed on 25 November 2026:

- Operating system installation and SSH connectivity succeeded.
- VM architecture, processor count and memory allocation were verified.
- Package repository access and dependency installation succeeded.
- MariaDB client connectivity and server versions were checked; both
  services are active and enabled.
- The required MariaDB character set and collation were verified.
- .NET 8 SDK and application runtimes were verified.
- PowerShell and supporting command-line utilities were verified.
- JPEG and HEIF/HEIC libvips loaders are available.
- Systemd is running and SSH is active.
- Both virtual machines were gracefully shut down and both clean
  checkpoints were verified as present.

#### Recovery checkpoints

| VM | Checkpoint | Created | Type |
| --- | --- | --- | --- |
| `OrchidApp-Debian12` | `Clean-Debian12-MariaDB10.11` | 25 November 2026 20:27:28 | Standard |
| `OrchidApp-Debian13` | `Clean-Debian13-MariaDB11.8` | 25 November 2026 21:12:07 | Standard |

Both VMs are currently off. Existing automatic checkpoints have been
retained. Checkpoint existence was verified; restoration was not
exercised. These checkpoints are not independent off-host backups.

#### Limitations and scope boundaries

- These x64 environments do not replace ARM64 Raspberry Pi acceptance.
- Hyper-V Default Switch NAT does not provide complete outbound network
  isolation from production systems.
- No production credentials or production database connections are
  configured. SSH addresses are dynamically allocated.
- No OrchidApp application installation or OrchidApp database creation
  has been undertaken.
- No specimen backup has been restored or modified.
- No application functional tests, actual photograph processing tests,
  or backup/restore tests have been undertaken.
- No production Raspberry Pi systems or operational backup arrangements
  have been changed.
- No application code, database migrations, tests, packaging or
  deployment scripts have been changed.

## 4. Fixed testing scope

| Ref | Test area | Windows | Linux |
| --- | --- | --- | --- |
| T01 | Application installation and deployment | Yes | Yes |
| T02 | Application startup and readiness | Yes | Yes |
| T03 | Database provisioning | Yes | Yes |
| T04 | Database migrations | Yes | Yes |
| T05 | Restoration of existing specimen backup | Yes | Yes |
| T06 | Core application functional workflows | Yes | Yes |
| T07 | Photograph upload and processing | Yes | Yes |
| T08 | Backup creation and validation | Yes | Yes |
| T09 | Backup restoration and data integrity | Yes | Yes |
| T10 | Application shutdown and restart | Yes | Yes |
| T11 | Windows launcher | Yes | No |
| T12 | Windows uninstall | Yes | No |
| T13 | Linux systemd services | No | Yes |
| T14 | Linux environment importer | No | Yes |
| T15 | Linux nightly backup and standby recovery | No | Yes |
| T16 | Application and database upgrade | Yes | Yes |

Detailed acceptance criteria must be established following the review
of existing tests and specimen backups under activity 05.

The existing test inventory and platform contracts remain authoritative
for implemented behaviour and existing validation procedures.

Reuse existing suitable tests. Do not duplicate working checks simply
to place them within a new framework.

Maximise shared application and browser tests. Introduce platform-
specific automation only where platform behaviour requires it.

Keep general OrchidApp installation independent of the owner's bespoke
monitoring environment. Test opt-in monitoring, importer and multi-
database backup behaviour using designated isolated fixtures.

Use existing photo checks and include representative large JPEG and
HEIC files.

Test final packaged Windows installers, not only development builds.

Test Linux deployment and recovery using the applicable documented
installation and upgrade procedures.

Do not treat a successful source build as evidence of successful
installation, upgrade, backup, restoration or recovery.

## 5. Specimen backups and test data

Reuse the existing Windows and Linux specimen backups.

Preserve original specimen files unchanged. Perform restoration,
migration and destructive testing only using isolated working copies.

During activity 05, establish:

- Exact specimen identity and source version.
- Archive checksum and expected contents.
- Applicable database and photograph integrity checks.
- Existing restoration and historical upgrade procedures.
- Existing test coverage and any genuine coverage gaps.

Record expected database records, photograph contents and other
relevant invariants using the existing specimen evidence.

Use the same specimens, expected results and acceptance criteria
for baseline and target testing wherever applicable.

Any version-specific differences must be documented and justified.

Do not introduce new specimen datasets unless the existing specimens
cannot support an agreed test requirement and the owner approves
the additional work.

Never use live collection data or production databases for destructive
testing.

## 6. Scope exclusions

The following are outside this programme:

- Moving away from .NET 8.
- Unrelated application functionality changes.
- User interface redesign.
- General database schema redesign.
- Performance optimisation unrelated to the MariaDB change.
- Exhaustive browser and operating system compatibility testing.
- Purchasing additional Windows licences or hardware.
- Revisiting previously resolved defects without new evidence.
- Unnecessary replacement of existing working test infrastructure.

## 7. Working and scope control rules

- Complete one numbered activity at a time.
- Obtain owner approval before expanding or changing the programme.
- Review and reuse existing work before creating replacements.
- Record unrelated findings as GitHub issues rather than immediately
  investigating or implementing them.
- Investigate blockers only sufficiently to determine whether they
  prevent completion of the current activity.
- Escalate material blockers and scope decisions to the owner.
- Carry out all development on the Windows DEV PC.
- Maintain code, scripts, tests and documentation in GitHub.
- Follow existing scoped-branch, pre-commit and validation rules.
- Do not make untracked changes to deployed application code.
- Work through implementation and troubleshooting one step at a time.
- Record actual test results and evidence.
- Do not claim unexecuted tests have passed.
- Do not reopen completed activities without new evidence.
- Do not perform destructive tests on production Raspberry Pis.
- Preserve existing operational backup and standby arrangements.

Any required change to the approved programme must be explicitly
agreed, documented and committed before implementation.

## 8. Completion gates

### Gate 1 - Current version baseline

Activities 04 to 09 must be complete.

Acceptance requires:

- Isolated Windows and Linux test environments.
- Review and reuse of existing automated checks.
- Identification and preservation of both specimen backups.
- Documented test scope and detailed acceptance criteria.
- Successful shared and platform-specific automated tests.
- Recorded baseline release, environment and validation evidence.
- Explicit identification of any platform or architecture limitations.
- Owner approval.

Do not commence activity 10, MariaDB 11.8 re-engineering, until
Gate 1 has been approved.

### Gate 2 - MariaDB 11.8 acceptance

Activities 10 to 12 must be complete.

Acceptance requires:

- Re-engineered Windows and Linux application and deployment components.
- MariaDB 11.8 dependency and packaging validation.
- Existing automated tests successfully repeated.
- Successful clean installation and deployment checks.
- Successful applicable MariaDB 10.11 to 11.8 upgrade scenarios.
- Successful specimen restoration and backup round-trip checks.
- Verified preservation of database records and photographs.
- Updated affected documentation and dependencies.
- Owner approval.

Do not commence release creation until Gate 2 has been approved.

### Gate 3 - Final release acceptance

Activities 13 and 14 must be complete.

Acceptance requires:

- Creation of the agreed new release.
- Validation of the actual final Windows release installer.
- Validation of the actual final Linux release artifacts.
- Successful applicable installation, upgrade and recovery checks.
- Appropriate ARM64 Raspberry Pi deployment verification.
- Recorded release artifact identities and acceptance evidence.
- Updated release documentation and upgrade instructions.
- Owner approval.

The programme is complete only after Gate 3 approval.

## 9. Progress and evidence

| Gate | Status | Approval evidence |
| --- | --- | --- |
| Gate 1 - Current version baseline | Approved | Owner approval on 28 November 2026 |
| Gate 2 - MariaDB 11.8 acceptance | Pending | Not yet approved |
| Gate 3 - Final release acceptance | Pending | Not yet approved |

Activities 01 to 04 are recorded as complete. Activity 04 establishes
and verifies the isolated Linux environments described above.

Activity 05 was completed on 26 November 2026. The owner approved the
[review record and acceptance criteria](activity-05-review.md), and
[PR #393](https://github.com/rayfeeney/OrchidApp/pull/393) merged at
`2796f88c7479e954354349f484786382be2c76b4`. All eight jobs passed in the
[CI run on that merge commit](https://github.com/rayfeeney/OrchidApp/actions/runs/45872438671).

Activity 06 was completed on 26 November 2026. The owner reviewed and
merged [PR #395](https://github.com/rayfeeney/OrchidApp/pull/395) at
`2842fe1d06cb980d2c263d51f4db212b75d8b8dc`. All eight jobs passed in the
[CI run on the merge commit](https://github.com/rayfeeney/OrchidApp/actions/runs/45889785873).
The [shared Playwright checks](../../tests/SharedBrowser.Checks/README.md)
passed on migrated and schema-only disposable MariaDB fixtures.
Installed package validation remains part of the platform activities and baseline.

Activity 07 was completed on 27 November 2026. The
[Windows Sandbox harness and evidence](../../tests/WindowsSandbox.Checks/README.md)
record the unpublished candidate installation, historical v1.4.0
upgrade, launcher backup and restore, restart, uninstall preservation,
and restoration into a separate fresh Sandbox.
[PR #400](https://github.com/rayfeeney/OrchidApp/pull/400) added the
launcher validation and [PR #401](https://github.com/rayfeeney/OrchidApp/pull/401)
completed the separate-target check. All eight jobs passed in the
[CI run on the final merge commit](https://github.com/rayfeeney/OrchidApp/actions/runs/46065642868).
Published-package baseline and provider-specific OneDrive acceptance remain open.

Activity 08 validation ran on 28 November 2026. The
[Linux-specific harness and evidence](../../tests/LinuxAcceptance.Checks/README.md)
record the installed Debian 12 x64 checks and the separate ARM64
historical specimen workflow, including the limits of each environment.
The owner reviewed and merged [PR #403](https://github.com/rayfeeney/OrchidApp/pull/403) at
`06902237fe536be1a896b751d7c079f1170fe662`. All eight jobs passed in the
[CI run on the merge commit](https://github.com/rayfeeney/OrchidApp/actions/runs/46138574117).

Activity 09 was completed on 28 November 2026. The owner accepted
the known Windows v1.4.1 baseline limitation. The verified published
installer passed installation and readiness with MariaDB 10.11.16 in
Windows Sandbox. Its startup backup reproduced the missing en-GB
ArchiveResources.psd1 failure. Specimen restore, browser writes, backup
round-trip and uninstall were unverified in that published run. The
[unpublished candidate results](../../tests/WindowsSandbox.Checks/README.md)
record the separate fix validation. Retest launcher backup, specimen
restore and backup round-trip in a fresh Sandbox on the next published
version containing the fix. The exact published Linux ARM64 package passed isolated historical upgrade and recovery. The [Activity 09 baseline review](activity-09-baseline-review.md) records the T01–T16 evidence and remaining limitations. The owner approved Activity 09 and Gate 1 after
[PR #405](https://github.com/rayfeeney/OrchidApp/pull/405) merged at
`7e7628cab39b6979fa38659cbb6f0dd6d3307f2d` and all eight jobs passed in
[post-merge CI](https://github.com/rayfeeney/OrchidApp/actions/runs/46142587657).

Next activity: 10 - Re-engineer OrchidApp for MariaDB 11.8.
Status: Pending.

Keep this document updated as each activity is completed. Link to
existing test inventories, CI results and release-specific acceptance
records rather than duplicating detailed evidence.

## 10. Related authoritative documentation

- [Repository instructions](../../AGENTS.md)
- [Contributing and validation](../../CONTRIBUTING.md)
- [Documentation index](../index.md)
- [Documentation ownership map](../documentation-map.md)
- [Current application state](../current-state.md)
- [Existing testing inventory and evidence](../testing-evidence.md)
- [Windows baseline acceptance](Windows-v1.4.0-Baseline-Acceptance.md)
- [Database creation](../database-creation.md)
- [Migration runners](../migration-runners.md)
- [Historical Linux upgrade testing](../historical-linux-upgrade.md)
- [Windows upgrade contract](../windows-upgrade-contract.md)
- [Windows installer recovery](../windows-installer-recovery.md)
- [Windows backup format](../windows-backup-format.md)
- [Linux installation and upgrade](../user-guides/linux/installation-upgrade.md)
- [Linux backup and restore](../user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md)
- [Linux nightly multi-database backup](../user-guides/linux/nightly-multi-database-backup.md)
- [Linux standby restore](../user-guides/linux/nightly-standby-restore.md)
- [Photo handling](../photo-handling.md)
- [Upgrade checklist](../upgrade-checklist.md)
