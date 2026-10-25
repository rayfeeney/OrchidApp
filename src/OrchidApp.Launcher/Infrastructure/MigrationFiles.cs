using System.Security.Cryptography;
using System.Text;

namespace OrchidApp.Launcher.Infrastructure;

internal static class MigrationFiles
{
    public static void RejectAliases(string path)
    {
        var current = new DirectoryInfo(Directory.Exists(path) ? path : Path.GetDirectoryName(path)!);
        for (; current is not null; current = current.Parent)
            if (current.Exists && (current.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new InvalidOperationException("Migration paths must not contain reparse points.");
        if (File.Exists(path) && (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            throw new InvalidOperationException("Migration file is a reparse point.");
    }

    public static List<MigrationFileEntry> Inventory(string root, bool legacy)
    {
        RejectAliases(root);
        var result = new List<MigrationFileEntry>();
        void Visit(string source, string relative)
        {
            RejectAliases(source);
            var directory = Directory.Exists(source);
            result.Add(new MigrationFileEntry { Path = relative.Replace('\\', '/'), IsDirectory = directory,
                Sha256 = directory ? null : Hash(source) });
            if (directory)
                foreach (var child in Directory.EnumerateFileSystemEntries(source).Order(StringComparer.OrdinalIgnoreCase))
                    Visit(child, Path.Combine(relative, Path.GetFileName(child)));
        }
        foreach (var (source, target) in new[] { ("data/mariadb", "data/mariadb"), (legacy ? "wwwroot/uploads" : "uploads", "uploads"), ("launcher-settings.json", "launcher-settings.json") })
        {
            var path = Path.Combine(root, source);
            if (File.Exists(path) || Directory.Exists(path)) Visit(path, target);
        }
        return result.OrderBy(e => e.Path, StringComparer.OrdinalIgnoreCase).ToList();
    }

    public static string Hash(string file)
    {
        using var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read);
        return Convert.ToHexString(SHA256.HashData(stream));
    }

    public static string Fingerprint(string root) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
        string.Join("\n", Inventory(root, true).Select(e => $"{e.Path}|{e.IsDirectory}|{e.Sha256}")))));

    public static string Child(string root, string relative)
    {
        var path = Path.GetFullPath(Path.Combine(root, relative));
        if (!path.StartsWith(Path.TrimEndingDirectorySeparator(Path.GetFullPath(root)) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Migration entry escapes its intended root.");
        RejectAliases(path);
        return path;
    }
}

public sealed class MigrationFileEntry
{
    public string Path { get; set; } = "";
    public bool IsDirectory { get; set; }
    public string? Sha256 { get; set; }
}
