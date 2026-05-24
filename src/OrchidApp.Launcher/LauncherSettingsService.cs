using System.Text.Json;

namespace OrchidApp.Launcher;

public sealed class LauncherSettingsService
{
    private readonly JsonSerializerOptions _jsonOptions = new()
    {
        WriteIndented = true
    };

    public string SettingsFilePath { get; }

    public LauncherSettingsService(string settingsFilePath)
    {
        if (string.IsNullOrWhiteSpace(settingsFilePath))
        {
            throw new ArgumentException("Settings file path must be provided.", nameof(settingsFilePath));
        }

        SettingsFilePath = settingsFilePath;
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
        var settingsDirectory = Path.GetDirectoryName(SettingsFilePath);

        if (!string.IsNullOrWhiteSpace(settingsDirectory))
        {
            Directory.CreateDirectory(settingsDirectory);
        }

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