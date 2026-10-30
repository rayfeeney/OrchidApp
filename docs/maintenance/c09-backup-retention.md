# C09 protected backup retention

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

The backup script now uses its declared SkipOldBackupPruning and BackupsToKeep controls instead of an undeclared PruneOldBackups variable. Normal defaults to three verified unprotected ZIPs and requires a minimum of one. The new ZIP is always retained. PreUpgrade never prunes; safety directories and paths recorded in restore/migration history are protected.

Only direct, recognised routine archives with matching metadata and supported payload validation can be counted/deleted. Unknown, corrupt, foreign or locked archives remain for review. Unreadable protection state stops pruning. Retention runs after new-backup verification and rechecks hashes/protection before removal; warnings leave the new valid backup usable. A same-directory backup lock serialises cooperating runs.

The launcher explicitly passes Normal, its routine directory and a keep count of three. Desktop SQL-update safety backups use backups/pre-migration with pruning disabled, separately from routine history. The packaging inventory now requires all three shared backup/restore helper files.

Retention fixtures exposed that Compress-Archive omits empty directories and hidden files. The shared archive writer now uses ZipFile.CreateFromDirectory, preserving those payload entries without changing version 2 format. Payload validation also reads hidden file metadata explicitly. This prevents empty-photo installations from producing an invalid ZIP and allows hidden uploads to pass validation before archiving.

## Validation

All 29 retention checks passed on PowerShell 7 and Windows PowerShell 5.1, covering default/minimum/disabled/pre-upgrade behavior, invalid counts, unrelated/foreign/corrupt/nested archives, pinned inputs and safety copies, corrupt history, pending recovery, protected directories, timestamp skew, deletion locks, older supported archives and hidden upload bytes. Existing 28 archive/journal policy checks also passed on both versions.

All 77 native MariaDB checks passed, including enabled/disabled retention, unrelated-copy preservation and failure-before-pruning checks alongside migration/restore regressions. All 13 staged Desktop checks passed, recording the real C# caller's backup arguments without writing its supplied directory. Web and launcher Release builds passed with zero warnings/errors; all 14 Development startup configuration checks passed. CI adds dual-PowerShell retention checks before Windows packaging; actionlint validation passed with its optional ShellCheck/Pyflakes integrations disabled. The new workflow still requires a GitHub Actions run.

Windows guide 04 is updated. All five embedded media files were preserved byte-identically and all six rendered pages were visually inspected. Existing screenshots illustrate launcher buttons; their historic log text is not the current retention policy. QA PDF/page images remain outside the source ZIP. Development startup configuration is unchanged; Program.cs changes are confined to the packaged pre-migration backup invocation.

## Limits

Retention is not an exact disk-space cap: protected or unrecognised files may increase the count. Candidate validation needs temporary space and can be slow on large backups. Retention does not provide an atomic cross-SQL/filesystem snapshot, cloud version history or authentication of an untrusted archive. Keep a verified off-computer recovery copy. Actual installer, full interactive installed-machine and historical-release acceptance remain separate.
