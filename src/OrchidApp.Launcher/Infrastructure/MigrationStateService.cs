using System.Text.Json;

namespace OrchidApp.Launcher.Infrastructure;

public sealed class MigrationStateService
{
    private readonly WindowsProgramDataPaths _paths;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public MigrationStateService(WindowsProgramDataPaths paths)
    {
        _paths = paths ?? throw new ArgumentNullException(nameof(paths));
    }

    public bool Exists()
    {
        return File.Exists(_paths.MigrationStateFile);
    }

    public MigrationState? Load()
    {
        if (!File.Exists(_paths.MigrationStateFile))
        {
            return null;
        }

        string json = File.ReadAllText(_paths.MigrationStateFile);

        if (string.IsNullOrWhiteSpace(json))
        {
            throw new InvalidOperationException("Migration state is empty. Preserve it and obtain support before startup.");
        }

        return JsonSerializer.Deserialize<MigrationState>(json, JsonOptions)
            ?? throw new InvalidOperationException("Migration state is null. Source review is required.");
    }

    public void Save(MigrationState state)
    {
        if (state is null)
        {
            throw new ArgumentNullException(nameof(state));
        }

        Directory.CreateDirectory(_paths.Root);

        string json = JsonSerializer.Serialize(state, JsonOptions);

        MigrationFiles.RejectAliases(_paths.MigrationStateFile);
        var temporary = _paths.MigrationStateFile + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                var bytes = System.Text.Encoding.UTF8.GetBytes(json);
                stream.Write(bytes);
                stream.Flush(flushToDisk: true);
            }
            if (File.Exists(_paths.MigrationStateFile)) File.Replace(temporary, _paths.MigrationStateFile, null);
            else File.Move(temporary, _paths.MigrationStateFile);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
