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
| 04 | Establish isolated Linux testing environments | Pending |
| 05 | Review existing automated tests and specimen backups | Pending |
| 06 | Implement shared application functional testing | Pending |
| 07 | Implement Windows-specific automated testing | Pending |
| 08 | Implement Linux-specific automated testing | Pending |
| 09 | Establish and approve Windows and Linux testing baselines | Pending |
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
| Linux acceptance environment | Isolated Linux testing environment |
| Linux virtualisation | Hyper-V proposed; configuration requires owner agreement |
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

The proposed Linux baseline is Debian 12 with MariaDB 10.11.
The proposed Linux target is Debian 13 with MariaDB 11.8.

The Linux environment configuration is not final until agreed by
the owner under activity 04.

An x64 Linux virtual machine does not replace ARM64 Raspberry Pi
acceptance. Record architecture-specific validation limits explicitly.

Use existing GitHub CI facilities where appropriate. Review existing
automation before introducing additional CI workflows or dependencies.

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
| Gate 1 - Current version baseline | Pending | Not yet approved |
| Gate 2 - MariaDB 11.8 acceptance | Pending | Not yet approved |
| Gate 3 - Final release acceptance | Pending | Not yet approved |

Activities 01 to 03 are recorded as owner-confirmed complete.

Current activity: 04 - Establish isolated Linux testing environments.

No automated testing baseline or MariaDB 11.8 release acceptance
is claimed by this initial planning document.

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
