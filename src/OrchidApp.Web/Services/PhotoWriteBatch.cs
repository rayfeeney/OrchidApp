using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace OrchidApp.Web.Services;

public sealed class PhotoRecoveryRegistry
{
    private readonly ConcurrentDictionary<string, byte> active = new(StringComparer.Ordinal);
    public void Add(string path) => active.TryAdd(path, 0);
    public void Remove(string path) => active.TryRemove(path, out _);
    public bool IsActive(string path) => active.ContainsKey(path);
}

// Upload files are compensated after known rollback; existing deletion files
// are removed only after confirmed commit. Unknown outcomes retain both.
public sealed class PhotoWriteBatch(string root, PhotoRecoveryRegistry registry,
    ILogger<PhotoWriteBatch> logger) : IDisposable
{
    private readonly HashSet<string> files = new(StringComparer.Ordinal);
    private readonly HashSet<string> deletions = new(StringComparer.Ordinal);
    public bool HasDeletions => deletions.Count != 0;
    public bool CleanupRequired { get; private set; }
    public void LogDeletionFailure(Exception error) => logger.LogError(error, "Plant photo deletion transaction failed");
    private readonly string journal = Path.Combine(root, ".photo-recovery", Guid.NewGuid().ToString("N") + ".json");
    private bool enabled;
    private bool resolved;
    public void Begin() => enabled = true;
    public void TrackDeletion(int plantId, IEnumerable<string> names)
    {
        if (!enabled) throw new InvalidOperationException("Photo deletion requires a write transaction.");
        // Validate everything before recording anything; rollback never deletes these files.
        var paths = names.Select(name => PhotoDeletionPaths.Resolve(root, plantId, name)).ToArray();
        var recoveryFolder = Path.Combine(root, ".photo-recovery");
        PhotoDeletionPaths.Validate(Path.Combine(recoveryFolder, "probe.json"));
        if (Directory.Exists(recoveryFolder) && Directory.EnumerateFiles(recoveryFolder)
            .Any(path => !registry.IsActive(path.EndsWith(".tmp", StringComparison.Ordinal) ? path[..^4] : path)))
            throw new InvalidOperationException("Photo recovery requires review before another change.");
        deletions.UnionWith(paths);
        registry.Add(journal);
        Write("DeletePrepared");
    }
    public void Track(IEnumerable<string> paths)
    {
        if (!enabled) return;
        var recoveryFolder = Path.Combine(root, ".photo-recovery");
        if (Directory.Exists(recoveryFolder) && Directory.EnumerateFiles(recoveryFolder)
            .Any(path => !registry.IsActive(path.EndsWith(".tmp", StringComparison.Ordinal) ? path[..^4] : path)))
            throw new InvalidOperationException("Photo recovery requires review before another upload. See the application log.");
        var prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        foreach (var path in paths)
        {
            var full = Path.GetFullPath(path);
            if (!full.StartsWith(prefix, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
                throw new InvalidOperationException("Invalid photo batch path.");
            files.Add(full);
        }
        if (files.Count == 0) return;
        registry.Add(journal); Write("Prepared");
    }
    private void Write(string state)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(journal)!);
        var record = JsonSerializer.Serialize(new { version = 1, state, createdUtc = DateTime.UtcNow,
            files = files.Concat(deletions).Select(p => Path.GetRelativePath(root, p)).ToArray() });
        using (var stream = new FileStream(journal + ".tmp", FileMode.Create, FileAccess.Write, FileShare.None))
        {
            var bytes = System.Text.Encoding.UTF8.GetBytes(record);
            stream.Write(bytes); stream.Flush(flushToDisk: true);
        }
        File.Move(journal + ".tmp", journal, overwrite: true);
    }
    public void BeforeCommit() { if (files.Count != 0 || HasDeletions) Write("CommitPending"); }
    public void Committed()
    {
        resolved = true;
        // Non-photo writes also use the completion filter. No tracked files
        // means no journal was created and there is nothing to clean up.
        if (files.Count == 0 && !HasDeletions) return;
        try
        {
            foreach (var path in deletions)
            {
                PhotoDeletionPaths.Validate(path);
                try { File.Delete(path); } // Missing historical files are already cleaned up.
                catch (DirectoryNotFoundException) { }
            }
            File.Delete(journal); File.Delete(journal + ".tmp");
        }
        catch (Exception ex)
        {
            CleanupRequired = true;
            try { Write("CommittedCleanupRequired"); } catch (Exception) { }
            logger.LogError(ex, "Committed photo journal requires review");
        }
        registry.Remove(journal);
    }
    public void RolledBack()
    {
        if (files.Count == 0 && !HasDeletions) { resolved = true; return; }
        bool failed = false;
        foreach (var path in files)
        {
            try { File.Delete(path); }
            catch (Exception ex) { failed = true; logger.LogError(ex, "Rolled-back photo file cleanup failed"); }
        }
        if (failed) { Retain("RollbackCleanupRequired"); return; }
        try
        {
            File.Delete(journal); File.Delete(journal + ".tmp"); resolved = true;
        }
        catch (Exception ex) { Retain("RollbackCleanupRequired", ex); }
        registry.Remove(journal);
    }
    public void Retain(string reason, Exception? error = null)
    {
        if (files.Count != 0 || HasDeletions)
        {
            try { Write(reason); }
            catch (Exception ex) { logger.LogError(ex, "Could not update photo recovery journal"); }
            logger.LogError(error, "Photo recovery requires review: {Reason}; journal {Journal}", reason, journal);
        }
        resolved = true; registry.Remove(journal);
    }
    public void Dispose()
    {
        if (!resolved && (files.Count != 0 || HasDeletions)) Retain("RequestOutcomeUnknown");
        registry.Remove(journal);
    }
}
