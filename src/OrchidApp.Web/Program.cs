using System.IO;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.Extensions.FileProviders;
using MySqlConnector;
using OrchidApp.Web.Data;
using OrchidApp.Web.Services;
using OrchidApp.Web.Infrastructure;
using OrchidApp.Web.Configuration;

var builder = WebApplication.CreateBuilder(args);
DevelopmentConfiguration.Apply(builder.Configuration, builder.Environment.EnvironmentName, builder.Environment.ContentRootPath);

Console.WriteLine("Program starting...");
Console.WriteLine($"ENV: {builder.Environment.EnvironmentName}");

if (builder.Environment.IsEnvironment("Desktop"))
{
    var uploadRootFromEnvironment =
        Environment.GetEnvironmentVariable("ORCHIDAPP_UPLOAD_ROOT");

    var desktopUploadsRoot = !string.IsNullOrWhiteSpace(uploadRootFromEnvironment)
        ? uploadRootFromEnvironment
        : Path.Combine(
            AppContext.BaseDirectory,
            "wwwroot",
            "uploads"
        );

    Directory.CreateDirectory(desktopUploadsRoot);

    builder.Configuration["Storage:UploadRoot"] = desktopUploadsRoot;

    Console.WriteLine(
        !string.IsNullOrWhiteSpace(uploadRootFromEnvironment)
            ? $"Desktop UploadRoot: {desktopUploadsRoot} Source: Environment"
            : $"Desktop UploadRoot: {desktopUploadsRoot} Source: AppContext fallback"
    );
}

// Add services to the container.
builder.Services.AddRazorPages(options =>
{
    options.Conventions.ConfigureFilter(new NavigationPageFilter());
    options.Conventions.ConfigureFilter(new Microsoft.AspNetCore.Mvc.TypeFilterAttribute(typeof(PlantWriteFilter)));
});

builder.Services.AddDbContext<OrchidDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("OrchidDb");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        throw new InvalidOperationException(
            "Connection string 'OrchidDb' is not configured. " +
            "Ensure Production provides it via environment configuration.");
    }

    options
        .UseMySql(connectionString, ServerVersion.AutoDetect(connectionString))
        .AddInterceptors(new CollationInterceptor());
});

builder.Services.AddSingleton<PhotoPipeline>();

builder.Services.Configure<MediaIngestionOptions>(
    builder.Configuration.GetSection("MediaIngestion"));

builder.Services.Configure<StorageSettings>(
    builder.Configuration.GetSection("Storage"));

builder.Services.AddScoped<StoragePathService>();

builder.Services.AddScoped<PhotoUrlService>();
builder.Services.AddMemoryCache();
builder.Services.AddSingleton(PlatformFeatures.FromConfiguration(builder.Configuration,
    OperatingSystem.IsLinux(), RuntimeInformation.OSArchitecture));
builder.Services.Configure<GreenhouseChartCacheOptions>(builder.Configuration.GetSection("GreenhouseCharts:Cache"));
builder.Services.AddSingleton<GreenhouseChartCache>();
builder.Services.AddScoped<IBotanicalNameSearch, BotanicalNameSearch>();
    
builder.Services.AddScoped<ObservationTypeResolver>();

builder.Services.AddScoped<IStoredProcedureExecutor, StoredProcedureExecutor>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}


// ---------- DESKTOP-ONLY DB BOOTSTRAP LOGIC ----------
if (app.Environment.IsEnvironment("Desktop"))
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
        ?? throw new Exception("DefaultConnection is not configured");

    var csBuilder = new MySqlConnector.MySqlConnectionStringBuilder(connectionString);
    var dbName = csBuilder.Database;
    if (!System.Text.RegularExpressions.Regex.IsMatch(dbName, "^[A-Za-z0-9_]{1,64}$"))
        throw new InvalidOperationException("Desktop bootstrap requires an explicit safe database identifier.");

    // Server-level connection (no DB)
    csBuilder.Database = "";

    using var conn = new MySqlConnector.MySqlConnection(csBuilder.ConnectionString);
    conn.Open();

    // Check if DB exists
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = @"
            SELECT SCHEMA_NAME 
            FROM INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = @db";

        cmd.Parameters.AddWithValue("@db", dbName);

        var result = cmd.ExecuteScalar();

        if (result == null)
        {
            Console.WriteLine("Creating your plant database...");

            using var createCmd = conn.CreateCommand();
            createCmd.CommandText = $@"
            CREATE DATABASE `{dbName}`
            CHARACTER SET utf8mb4
            COLLATE utf8mb4_unicode_ci;";
            createCmd.ExecuteNonQuery();

            Console.WriteLine("Plant database created.");
        }
        else
        {
            Console.WriteLine("DB already exists");
        }
    }

    // ---------- DB connection (after DB exists) ----------
    using (var dbConn = new MySqlConnector.MySqlConnection(connectionString))
    {
        dbConn.Open();

        var runtimeRoot = AppContext.BaseDirectory;

        var dbFolder = Path.Combine(runtimeRoot, "database");
        var mariadbRoot = Path.Combine(runtimeRoot, "runtime", "mariadb");

        string platformFolder = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "win-x64" :
                                RuntimeInformation.IsOSPlatform(OSPlatform.OSX) ? "osx-arm64" :
                                throw new Exception("Unsupported platform");

        string exeName = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "mariadb.exe" : "mariadb";

        var mariadbExe = Path.Combine(
            mariadbRoot,
            platformFolder,
            "bin",
            exeName
        );

Console.WriteLine($"RuntimeRoot: {runtimeRoot}");
Console.WriteLine($"DB Folder: {dbFolder}");
Console.WriteLine($"MariaDB EXE: {mariadbExe}");

        bool didBootstrapSchema = false;
        bool schemaExists;

        using (var cmd = dbConn.CreateCommand())
        {
            cmd.CommandText = @"
                SELECT COUNT(*)
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = @db
                AND TABLE_NAME = 'schemaversion';";

            cmd.Parameters.AddWithValue("@db", dbName);

            var result = Convert.ToInt32(cmd.ExecuteScalar());
            schemaExists = result > 0;
        }

        if (schemaExists)
        {
            Console.WriteLine("Existing plant database found.");
        }
        else
        {
            didBootstrapSchema = true;

            Console.WriteLine("Setting up OrchidApp for first use...");

            var schemaRoot = Path.Combine(dbFolder, "schema");
            var baseline = SchemaBaseline.Load(schemaRoot);
            using (var emptyCheck = dbConn.CreateCommand())
            {
                emptyCheck.CommandText = @"SELECT
                    (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()) +
                    (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE())";
                if (Convert.ToInt32(emptyCheck.ExecuteScalar()) != 0)
                    throw new InvalidOperationException("First-time setup requires an empty database. Existing or partial data must be reviewed, not overwritten.");
            }
            foreach (var item in baseline.Files)
                RunScriptWithMariaDb(Path.Combine(schemaRoot, item.Path), mariadbExe, connectionString);

            // Written only after every object and required seed has succeeded.
            using var recordBaseline = dbConn.CreateCommand();
            recordBaseline.CommandText = "INSERT INTO schemaversion (scriptName, checksum) VALUES (@name, @checksum)";
            recordBaseline.Parameters.AddWithValue("@name", baseline.Marker);
            recordBaseline.Parameters.AddWithValue("@checksum", baseline.ManifestChecksum);
            recordBaseline.ExecuteNonQuery();
            Console.WriteLine("Finishing first-time setup...");

        }

        var migrationsFolder = Path.Combine(dbFolder, "migrations");

        if (didBootstrapSchema)
        {
            Console.WriteLine("Your plant database is ready.");
        }
        else
        {
            RunMigrations(migrationsFolder, mariadbExe, dbConn, runtimeRoot, connectionString);
        }
    }

    
}
// ------------------------------------------------------------




// app.UseHttpsRedirection();

app.UseStaticFiles(); // always serve wwwroot (Dev + Prod)

var uploadsPath = builder.Configuration["Storage:UploadRoot"];

if (Directory.Exists(uploadsPath))
{
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(uploadsPath),
        RequestPath = "/uploads"
    });
}

app.UseRouting();

app.UseAuthorization();

app.MapRazorPages();

app.Run();

static void RunScriptWithMariaDb(string scriptPath, string mariadbExe, string connectionString, string? sqlSnapshot = null)
{
    Console.WriteLine($"Setting up database item: {Path.GetFileName(scriptPath)}");

    var process = new Process
    {
        StartInfo = new ProcessStartInfo
        {
            FileName = mariadbExe,
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        }
    };

    var connection = new MySqlConnectionStringBuilder(connectionString);
    foreach (var argument in new[] { "--no-defaults", "--protocol=TCP", "--host=" + connection.Server,
        "--port=" + connection.Port, "--user=" + connection.UserID, "--database=" + connection.Database,
        "--default-character-set=utf8mb4", "--connect-timeout=5", "--abort-source-on-error" })
        process.StartInfo.ArgumentList.Add(argument);
    process.StartInfo.Environment["MYSQL_PWD"] = connection.Password;
    process.StartInfo.StandardInputEncoding = System.Text.Encoding.UTF8;

    process.OutputDataReceived += (s, e) =>
    {
        if (e.Data != null)
            Console.WriteLine(e.Data);
    };

    process.ErrorDataReceived += (s, e) =>
    {
        if (e.Data != null)
            Console.WriteLine("ERR: " + e.Data);
    };

    process.Start();

    // START READING BEFORE WRITING
    process.BeginOutputReadLine();
    process.BeginErrorReadLine();

    var sql = "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;\n" + (sqlSnapshot ?? File.ReadAllText(scriptPath)) + "\n";

    process.StandardInput.Write(sql);
    process.StandardInput.Close();

    process.WaitForExit();

    if (process.ExitCode != 0)
    {
        throw new Exception(
            $"Database script failed: {Path.GetFileName(scriptPath)}"
        );
    }
}

static void RunPreMigrationBackup(string runtimeRoot)
{
    var backupScript = Path.Combine(
        runtimeRoot,
        "tools",
        "backup-orchidapp.ps1"
    );

    if (!File.Exists(backupScript))
    {
        throw new Exception(
            $"Pre-update backup cannot run because the backup script was not found: {backupScript}"
        );
    }

    Console.WriteLine("Creating a safety backup before applying database updates...");

    using var process = new Process
    {
        StartInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            WorkingDirectory = runtimeRoot,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        }
    };
    var safetyRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "OrchidApp", "backups", "pre-migration");
    foreach (var argument in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", backupScript,
        "-BackupType", "Normal", "-BackupsRoot", safetyRoot, "-SkipOldBackupPruning" })
        process.StartInfo.ArgumentList.Add(argument);

    process.OutputDataReceived += (s, e) =>
    {
        if (!string.IsNullOrWhiteSpace(e.Data))
        {
            Console.WriteLine(e.Data);
        }
    };

    process.ErrorDataReceived += (s, e) =>
    {
        if (!string.IsNullOrWhiteSpace(e.Data))
        {
            Console.WriteLine("ERR: " + e.Data);
        }
    };

    process.Start();

    process.BeginOutputReadLine();
    process.BeginErrorReadLine();

    process.WaitForExit();

    if (process.ExitCode != 0)
    {
        throw new Exception(
            "Database updates cannot be applied because the safety backup failed."
        );
    }

    Console.WriteLine("Safety backup completed.");
}

static string[] MigrationFiles(string folder) => Directory.Exists(folder)
    ? Directory.GetFiles(folder).Where(path => Path.GetExtension(path).Equals(".sql", StringComparison.OrdinalIgnoreCase)).ToArray()
    : [];

static void RunMigrations(string folderPath, string mariadbExe, MySqlConnection dbConn, string runtimeRoot, string connectionString)
{
    var pendingFiles = MigrationHistory.Plan(MigrationFiles(folderPath), SchemaBaseline.ReadHistory(dbConn));
    if (pendingFiles.Count > 0)
    {
        Console.WriteLine($"Database updates are available: {pendingFiles.Count}");
        RunPreMigrationBackup(runtimeRoot);
    }
    foreach (var item in pendingFiles)
    {
        var acquired = false;
        var sqlStarted = false;
        try
        {
            using (var acquire = dbConn.CreateCommand())
            {
                acquire.CommandText = "INSERT INTO schemaversion(scriptName,checksum) VALUES (@name,@checksum)";
                acquire.Parameters.AddWithValue("@name", MigrationHistory.PendingMarker);
                acquire.Parameters.AddWithValue("@checksum", item.Checksum);
                acquire.ExecuteNonQuery();
                acquired = true;
            }
            var current = SchemaBaseline.ReadHistory(dbConn);
            if (current[MigrationHistory.PendingMarker] != item.Checksum)
                throw new InvalidOperationException("Migration ownership marker changed.");
            current.Remove(MigrationHistory.PendingMarker);
            var selected = MigrationHistory.Plan(MigrationFiles(folderPath), current).SingleOrDefault(file => file.Name == item.Name);
            if (selected is null)
            {
                ClearPending(dbConn, item.Checksum);
                continue;
            }
            if (selected.Checksum != item.Checksum)
                throw new InvalidOperationException("Migration changed after preflight: " + item.Name);
            Console.WriteLine("Applying database update: " + item.Name);
            sqlStarted = true;
            RunScriptWithMariaDb(item.Path, mariadbExe, connectionString, item.Sql);
            using var tx = dbConn.BeginTransaction();
            using var record = dbConn.CreateCommand();
            record.Transaction = tx;
            record.CommandText = @"INSERT INTO schemaversion(scriptName,checksum) VALUES (@name,@checksum);
                DELETE FROM schemaversion WHERE scriptName='migration:pending' AND checksum=@checksum;";
            record.Parameters.AddWithValue("@name", item.Name);
            record.Parameters.AddWithValue("@checksum", item.Checksum);
            record.ExecuteNonQuery();
            tx.Commit();
        }
        catch (Exception error)
        {
            if (acquired && !sqlStarted) ClearPending(dbConn, item.Checksum);
            if (acquired && sqlStarted)
                throw new InvalidOperationException($"Migration '{item.Name}' failed or could not be confirmed. SQL may be partially applied; no automatic DDL rollback is promised. Preserve the error and inspect migration:pending before any retry.", error);
            throw;
        }
    }
    if (pendingFiles.Count == 0) Console.WriteLine("Database is up to date.");
    else
    {
        VerifyMigrationsApplied(pendingFiles.Select(file => file.Path), dbConn);
        Console.WriteLine($"Database updates applied: {pendingFiles.Count}");
    }
}

static void ClearPending(MySqlConnection connection, string checksum)
{
    using var clear = connection.CreateCommand();
    clear.CommandText = "DELETE FROM schemaversion WHERE scriptName='migration:pending' AND checksum=@checksum";
    clear.Parameters.AddWithValue("@checksum", checksum);
    clear.ExecuteNonQuery();
}

static void VerifyMigrationsApplied(
    IEnumerable<string> migrationFiles,
    MySqlConnection dbConn)
{
    foreach (var file in migrationFiles)
    {
        var scriptName = Path.GetFileName(file);
        var checksum = ComputeChecksum(file);

        using var cmd = dbConn.CreateCommand();
        cmd.CommandText = @"
            SELECT checksum
            FROM schemaversion
            WHERE scriptName = @name";

        cmd.Parameters.AddWithValue("@name", scriptName);

        var storedChecksum = cmd.ExecuteScalar() as string;

        if (string.IsNullOrWhiteSpace(storedChecksum))
        {
            throw new Exception(
                $"Database update verification failed. '{scriptName}' was not recorded."
            );
        }

        if (!string.Equals(storedChecksum, checksum, StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception(
                $"Database update verification failed. '{scriptName}' checksum does not match."
            );
        }
    }

    Console.WriteLine("Database update verification passed.");
}

static string ComputeChecksum(string filePath)
{
    using var sha = SHA256.Create();
    var bytes = File.ReadAllBytes(filePath);
    var hash = sha.ComputeHash(bytes);

    return Convert.ToHexString(hash); // .NET 5+
}
