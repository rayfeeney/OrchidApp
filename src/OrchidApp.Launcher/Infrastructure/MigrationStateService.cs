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
            return null;
        }

        return JsonSerializer.Deserialize<MigrationState>(json, JsonOptions);
    }

    public void Save(MigrationState state)
    {
        if (state is null)
        {
            throw new ArgumentNullException(nameof(state));
        }

        Directory.CreateDirectory(_paths.Root);

        string json = JsonSerializer.Serialize(state, JsonOptions);

        File.WriteAllText(_paths.MigrationStateFile, json);
    }
}