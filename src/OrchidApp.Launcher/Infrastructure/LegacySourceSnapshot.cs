using System.Text.Json;

namespace OrchidApp.Launcher.Infrastructure;

// Capture only while every source file denies writes/deletion. Never copy live DB files.
internal static class LegacySourceSnapshot
{
    public static string Capture(string sourceRoot, string stagingParent)
    {
        sourceRoot = Path.GetFullPath(sourceRoot);
        if (!Directory.Exists(Path.Combine(sourceRoot, "data", "mariadb", "orchids")) ||
            !Directory.EnumerateFileSystemEntries(Path.Combine(sourceRoot, "data", "mariadb", "orchids")).Any())
            throw new InvalidOperationException("The selected legacy source has no populated data/mariadb/orchids directory.");
        var parent = Path.GetFullPath(stagingParent);
        var sourcePrefix = Path.TrimEndingDirectorySeparator(sourceRoot) + Path.DirectorySeparatorChar;
        if (parent.Equals(sourceRoot, StringComparison.OrdinalIgnoreCase) || parent.StartsWith(sourcePrefix, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Legacy staging must be outside the source installation.");
        for (var ancestor = new DirectoryInfo(parent); ancestor is not null; ancestor = ancestor.Parent)
            if (ancestor.Exists && (ancestor.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new InvalidOperationException("Legacy staging contains a reparse point.");
        var roots = new[] { "data/mariadb", "wwwroot/uploads", "launcher-settings.json" };
        List<string> Inventory()
        {
            var result = new List<string>();
            void Visit(string path)
            {
                for (var ancestor = new DirectoryInfo(Directory.Exists(path) ? path : Path.GetDirectoryName(path)!); ancestor is not null; ancestor = ancestor.Parent)
                    if ((ancestor.Attributes & FileAttributes.ReparsePoint) != 0) throw new InvalidOperationException("Legacy source component contains a reparse point.");
                if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
                    throw new InvalidOperationException("Legacy data contains a reparse point; source review is required.");
                result.Add(Path.GetRelativePath(sourceRoot, path));
                if (Directory.Exists(path)) foreach (var child in Directory.EnumerateFileSystemEntries(path).Order(StringComparer.OrdinalIgnoreCase)) Visit(child);
            }
            // Also reject aliases in ancestors/components, not only leaf files.
            for (var directory = new DirectoryInfo(sourceRoot); directory is not null; directory = directory.Parent)
                if ((directory.Attributes & FileAttributes.ReparsePoint) != 0) throw new InvalidOperationException("Legacy source root contains a reparse point.");
            foreach (var relative in roots)
            {
                var path = Path.Combine(sourceRoot, relative);
                if (File.Exists(path) || Directory.Exists(path)) Visit(path);
            }
            return result.Order(StringComparer.OrdinalIgnoreCase).ToList();
        }
        var before = Inventory();
        var held = new Dictionary<string, FileStream>(StringComparer.OrdinalIgnoreCase);
        string? snapshot = null;
        try
        {
            foreach (var relative in before.Where(p => File.Exists(Path.Combine(sourceRoot, p))))
                held.Add(relative, new FileStream(Path.Combine(sourceRoot, relative), FileMode.Open, FileAccess.Read, FileShare.Read));
            if (!before.SequenceEqual(Inventory(), StringComparer.OrdinalIgnoreCase)) throw new IOException("Legacy source changed while acquiring its read locks.");
            var sourceFingerprint = MigrationFiles.Fingerprint(sourceRoot);
            snapshot = Path.Combine(parent, "legacy-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(snapshot);
            foreach (var relative in before)
            {
                var target = Path.Combine(snapshot, relative);
                if (held.TryGetValue(relative, out var stream))
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                    using var output = new FileStream(target, FileMode.CreateNew, FileAccess.Write, FileShare.None);
                    stream.CopyTo(output);
                }
                else Directory.CreateDirectory(target);
            }
            if (!before.SequenceEqual(Inventory(), StringComparer.OrdinalIgnoreCase)) throw new IOException("Legacy source changed during capture; migration must stop.");
            File.WriteAllText(Path.Combine(snapshot, "source-capture.json"), JsonSerializer.Serialize(new { originalRoot = sourceRoot, capturedAtUtc = DateTime.UtcNow, sourceFingerprint }));
            return snapshot;
        }
        catch (IOException ex)
        {
            throw new InvalidOperationException("Legacy source is busy, changed, or could not be captured. Close the old OrchidApp/database and retry after review. No migration is authorised by this failed capture." + (snapshot is null ? "" : " Incomplete staging: " + snapshot), ex);
        }
        finally { foreach (var stream in held.Values) stream.Dispose(); }
    }
}
