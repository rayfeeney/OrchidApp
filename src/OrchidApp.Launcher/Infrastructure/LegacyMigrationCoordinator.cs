using System.Text.Json;

namespace OrchidApp.Launcher.Infrastructure;

internal sealed class LegacyMigrationCoordinator(WindowsProgramDataPaths paths, Action<string>? checkpoint = null)
{
    private readonly MigrationStateService states = new(paths);
    private string TargetToken => Path.Combine(paths.Root, "migration-target-id");
    public const string Copying = "Copying";
    public const string AwaitingReadiness = "AwaitingReadiness";

    public FileStream AcquireLock()
    {
        MigrationFiles.RejectAliases(paths.Root);
        Directory.CreateDirectory(paths.Root);
        var file = Path.Combine(paths.Root, "migration.lock");
        MigrationFiles.RejectAliases(file);
        return new FileStream(file, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
    }

    public MigrationState Begin(string source, string snapshot, string backup)
    {
        if (states.Exists()) throw new InvalidOperationException("Existing migration state must be reconciled before another migration.");
        AssertEmptyTarget();
        using var receipt = JsonDocument.Parse(File.ReadAllText(Path.Combine(snapshot, "source-capture.json")));
        if (!SamePath(receipt.RootElement.GetProperty("originalRoot").GetString()!, source))
            throw new InvalidOperationException("Captured source identity differs from the selected source.");
        if (!File.Exists(backup)) throw new InvalidOperationException("Verified pre-upgrade backup is missing.");
        // The launcher pre-creates the target uploads root even for sources without photos.
        Directory.CreateDirectory(Path.Combine(snapshot, "wwwroot", "uploads"));
        var state = new MigrationState { SchemaVersion = 2, MigrationStatus = MigrationStatus.Started,
            MigrationStartedAtUtc = DateTime.UtcNow, Phase = Copying, OperationId = Guid.NewGuid().ToString("N"),
            SourceLegacyRootPath = Path.GetFullPath(source), SnapshotRootPath = Path.GetFullPath(snapshot),
            SourceFingerprint = receipt.RootElement.GetProperty("sourceFingerprint").GetString(),
            TargetProgramDataRootPath = paths.Root, PreUpgradeBackupPath = Path.GetFullPath(backup),
            CopyManifest = MigrationFiles.Inventory(snapshot, true) };
        Validate(state);
        states.Save(state); // Must persist ownership before the first target write.
        return state;
    }

    public void Validate(MigrationState state)
    {
        MigrationFiles.RejectAliases(TargetToken);
        if (state.SchemaVersion != 2 || !Guid.TryParseExact(state.OperationId, "N", out _) ||
            !SamePath(state.TargetProgramDataRootPath, paths.Root) ||
            string.IsNullOrWhiteSpace(state.SourceLegacyRootPath) || state.SourceFingerprint?.Length != 64 ||
            state.CopyManifest is not { Count: > 0 } ||
            state.MigrationStatus is not (MigrationStatus.Started or MigrationStatus.Failed or MigrationStatus.Completed) ||
            state.Phase is not (Copying or AwaitingReadiness or "Completed"))
            throw new InvalidOperationException("Migration state is unsupported/incomplete. Preserve sources, target and state for support; do not infer completion.");
        if ((state.Phase == "Completed") != (state.MigrationStatus == MigrationStatus.Completed) ||
            !state.CopyManifest.Any(e => !e.IsDirectory && e.Path.StartsWith("data/mariadb/orchids/", StringComparison.Ordinal)))
            throw new InvalidOperationException("Migration state does not identify a populated copied database and valid completion phase.");
        if (state.MigrationStatus == MigrationStatus.Completed &&
            (state.Phase != "Completed" || state.MigrationCompletedAtUtc is null || !state.MigratedMariaDbData))
            throw new InvalidOperationException("Migration completion has no readiness evidence.");
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var entry in state.CopyManifest!)
        {
            if (!(entry.Path == "data/mariadb" || entry.Path.StartsWith("data/mariadb/", StringComparison.Ordinal) || entry.Path == "uploads" || entry.Path.StartsWith("uploads/", StringComparison.Ordinal) || entry.Path == "launcher-settings.json") ||
                !seen.Add(entry.Path) || (!entry.IsDirectory && (entry.Sha256?.Length != 64)))
                throw new InvalidOperationException("Migration copy inventory is invalid.");
            MigrationFiles.Child(paths.Root, entry.Path);
        }
        if (state.MigrationStatus == MigrationStatus.Completed || state.Phase == AwaitingReadiness)
            AssertTargetIdentity(state);
        else if (File.Exists(TargetToken) && File.ReadAllText(TargetToken) != state.OperationId)
            throw new InvalidOperationException("ProgramData migration ownership differs from the recorded operation.");
    }

    public void ContinueCopy(MigrationState state)
    {
        Validate(state);
        if (state.MigrationStatus == MigrationStatus.Completed || state.Phase == AwaitingReadiness) return;
        var snapshot = state.SnapshotRootPath ?? throw new InvalidOperationException("Captured source is missing.");
        var staging = Path.Combine(paths.Root, "migration-staging");
        MigrationFiles.Child(staging, Path.GetRelativePath(staging, snapshot));
        if (!File.Exists(state.PreUpgradeBackupPath)) throw new InvalidOperationException("Pre-upgrade backup is missing; no copy resume is authorised.");
        var inventory = MigrationFiles.Inventory(snapshot, true);
        if (!SameInventory(inventory, state.CopyManifest!)) throw new InvalidOperationException("Captured source changed; do not overwrite or resume from a different capture.");
        if (!File.Exists(TargetToken))
        {
            AssertEmptyTarget();
            using var token = new StreamWriter(new FileStream(TargetToken, FileMode.CreateNew, FileAccess.Write, FileShare.None));
            token.Write(state.OperationId);
        }
        // Every existing target component must be an exact member of this operation.
        var expected = state.CopyManifest!.ToDictionary(e => e.Path, StringComparer.OrdinalIgnoreCase);
        foreach (var entry in MigrationFiles.Inventory(paths.Root, false))
            if (!expected.TryGetValue(entry.Path, out var owned) || owned.IsDirectory != entry.IsDirectory || owned.Sha256 != entry.Sha256)
                throw new InvalidOperationException("Partial target contains changed or unrelated data. Preserve it and obtain support; no overwrite is authorised.");
        var work = MigrationFiles.Child(paths.Root, "migration-work/" + state.OperationId);
        Directory.CreateDirectory(work);
        foreach (var entry in state.CopyManifest!)
        {
            var target = MigrationFiles.Child(paths.Root, entry.Path);
            if (entry.IsDirectory) { Directory.CreateDirectory(target); continue; }
            if (File.Exists(target)) continue;
            var relative = entry.Path.StartsWith("uploads/", StringComparison.Ordinal) || entry.Path == "uploads" ? "wwwroot/" + entry.Path : entry.Path;
            var source = MigrationFiles.Child(snapshot, relative);
            var temporary = Path.Combine(work, Guid.NewGuid().ToString("N"));
            File.Copy(source, temporary, overwrite: false);
            if (MigrationFiles.Hash(temporary) != entry.Sha256) throw new InvalidOperationException("Captured file changed during copying.");
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            File.Move(temporary, target); // Atomic per file; never replace an existing target.
            checkpoint?.Invoke("CopiedFile");
        }
        if (!SameInventory(MigrationFiles.Inventory(paths.Root, false), state.CopyManifest))
            throw new InvalidOperationException("Copied target does not match the captured inventory.");
        state.MigratedMariaDbData = true;
        state.MigratedUploads = state.CopyManifest.Any(e => e.Path == "uploads");
        state.MigratedLauncherSettings = state.CopyManifest.Any(e => e.Path == "launcher-settings.json");
        state.Phase = AwaitingReadiness;
        state.MigrationStatus = MigrationStatus.Started;
        state.ErrorMessage = null;
        checkpoint?.Invoke("BeforeReadinessState");
        states.Save(state);
    }

    public void CompleteAfterReadiness(MigrationState state)
    {
        Validate(state);
        if (state.Phase != AwaitingReadiness) throw new InvalidOperationException("Copy has not reached readiness verification.");
        if (Directory.Exists(state.SourceLegacyRootPath)) CheckPreservedSource(state, state.SourceLegacyRootPath);
        state.Phase = "Completed";
        state.MigrationStatus = MigrationStatus.Completed;
        state.MigrationCompletedAtUtc = DateTime.UtcNow;
        state.FailedAtUtc = null;
        state.ErrorMessage = null;
        try { states.Save(state); }
        catch
        {
            state.Phase = AwaitingReadiness;
            state.MigrationStatus = MigrationStatus.Started;
            state.MigrationCompletedAtUtc = null;
            throw;
        }
    }

    public void CheckPreservedSource(MigrationState state, string candidate)
    {
        if (!SamePath(candidate, state.SourceLegacyRootPath) || MigrationFiles.Fingerprint(candidate) != state.SourceFingerprint)
            throw new InvalidOperationException("A discovered legacy source differs from the preserved migration source. Startup stopped for source review.");
    }

    private void AssertTargetIdentity(MigrationState state)
    {
        MigrationFiles.RejectAliases(TargetToken);
        var orchids = Path.Combine(paths.MariaDbData, "orchids");
        if (!File.Exists(TargetToken) || File.ReadAllText(TargetToken) != state.OperationId ||
            !Directory.Exists(orchids) || !Directory.EnumerateFileSystemEntries(orchids).Any())
            throw new InvalidOperationException("Recorded ProgramData target is missing or belongs to a different migration. Startup must stop.");
    }

    private void AssertEmptyTarget()
    {
        MigrationFiles.RejectAliases(paths.MariaDbData);
        MigrationFiles.RejectAliases(paths.Uploads);
        if (File.Exists(TargetToken) || File.Exists(paths.LauncherSettingsFile) ||
            (Directory.Exists(paths.MariaDbData) && Directory.EnumerateFileSystemEntries(paths.MariaDbData).Any()) ||
            (Directory.Exists(paths.Uploads) && Directory.EnumerateFileSystemEntries(paths.Uploads).Any()))
            throw new InvalidOperationException("ProgramData contains existing data/settings or migration ownership. No overwrite is authorised.");
        MigrationFiles.RejectAliases(paths.Root);
        Directory.CreateDirectory(paths.Root);
    }

    private static bool SameInventory(List<MigrationFileEntry> left, List<MigrationFileEntry> right) =>
        left.Count == right.Count && left.Zip(right).All(p => p.First.Path == p.Second.Path && p.First.IsDirectory == p.Second.IsDirectory && p.First.Sha256 == p.Second.Sha256);
    public static bool SamePath(string left, string right) => string.Equals(Path.TrimEndingDirectorySeparator(Path.GetFullPath(left)), Path.TrimEndingDirectorySeparator(Path.GetFullPath(right)), StringComparison.OrdinalIgnoreCase);
}
