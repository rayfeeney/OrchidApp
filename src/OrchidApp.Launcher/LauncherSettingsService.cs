using System.Text.Json;

namespace OrchidApp.Launcher;

public sealed class LauncherSettingsService
{
    private const string SettingsFileName = "launcher-settings.json";

    private readonly JsonSerializerOptions _jsonOptions = new()
    {
        WriteIndented = true
    };

    public string SettingsFilePath { get; }

    public LauncherSettingsService()
    {
        SettingsFilePath = Path.Combine(
            AppContext.BaseDirectory,
            SettingsFileName);
    }

    public LauncherSettings Load()
    {
        if (!File.Exists(SettingsFilePath))
        {
            return new LauncherSettings();
        }

        var json = File.ReadAllText(SettingsFilePath);

        if (string.IsNullOrWhiteSpace(json))
        {
            return new LauncherSettings();
        }

        return JsonSerializer.Deserialize<LauncherSettings>(json, _jsonOptions)
            ?? new LauncherSettings();
    }

    public void Save(LauncherSettings settings)
    {
        var json = JsonSerializer.Serialize(settings, _jsonOptions);

        File.WriteAllText(SettingsFilePath, json);
    }

    public bool TryValidateCloudBackupFolder(
        string? folderPath,
        out string validationMessage)
    {
        validationMessage = string.Empty;

        if (string.IsNullOrWhiteSpace(folderPath))
        {
            validationMessage = "Choose a cloud backup folder.";
            return false;
        }

        if (!Directory.Exists(folderPath))
        {
            validationMessage = "The selected folder does not exist.";
            return false;
        }

        try
        {
            var testFilePath = Path.Combine(
                folderPath,
                $".orchidapp-write-test-{Guid.NewGuid():N}.tmp");

            File.WriteAllText(testFilePath, "test");
            File.Delete(testFilePath);
        }
        catch (Exception ex)
        {
            validationMessage = $"The selected folder is not writable. {ex.Message}";
            return false;
        }

        return true;
    }
}