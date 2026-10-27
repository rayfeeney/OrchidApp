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

// Retain files after an unknown commit outcome; delete only after known rollback.
public sealed class PhotoWriteBatch(string root, PhotoRecoveryRegistry registry,
    ILogger<PhotoWriteBatch> logger) : IDisposable
{
    private readonly HashSet<string> files = new(StringComparer.Ordinal);
    private readonly string journal = Path.Combine(root, ".photo-recovery", Guid.NewGuid().ToString("N") + ".json");
    private bool enabled;
    private bool resolved;
    public void Begin() => enabled = true;
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
        registry.Add(journal); Write("Prepared");
    }
    private void Write(string state)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(journal)!);
        var record = JsonSerializer.Serialize(new { version = 1, state, createdUtc = DateTime.UtcNow,
            files = files.Select(p => Path.GetRelativePath(root, p)).ToArray() });
        using (var stream = new FileStream(journal + ".tmp", FileMode.Create, FileAccess.Write, FileShare.None))
        {
            var bytes = System.Text.Encoding.UTF8.GetBytes(record);
            stream.Write(bytes); stream.Flush(flushToDisk: true);
        }
        File.Move(journal + ".tmp", journal, overwrite: true);
    }
    public void BeforeCommit() { if (files.Count != 0) Write("CommitPending"); }
    public void Committed()
    {
        resolved = true;
        try { File.Delete(journal); File.Delete(journal + ".tmp"); }
        catch (Exception ex)
        {
            try { Write("CommittedCleanupRequired"); } catch (Exception) { }
            logger.LogError(ex, "Committed photo journal requires review");
        }
        registry.Remove(journal);
    }
    public void RolledBack()
    {
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
        if (files.Count != 0)
        {
            try { Write(reason); }
            catch (Exception ex) { logger.LogError(ex, "Could not update photo recovery journal"); }
            logger.LogError(error, "Photo recovery requires review: {Reason}; journal {Journal}", reason, journal);
        }
        resolved = true; registry.Remove(journal);
    }
    public void Dispose()
    {
        if (!resolved && files.Count != 0) Retain("RequestOutcomeUnknown");
        registry.Remove(journal);
    }
}
