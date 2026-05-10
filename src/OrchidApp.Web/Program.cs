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

Console.WriteLine("Program starting...");
Console.WriteLine($"ENV: {builder.Environment.EnvironmentName}");

if (builder.Environment.IsEnvironment("Desktop"))
{
    var desktopUploadsRoot = Path.Combine(
        AppContext.BaseDirectory,
        "wwwroot",
        "uploads"
    );

    Directory.CreateDirectory(desktopUploadsRoot);

    builder.Configuration["Storage:UploadRoot"] = desktopUploadsRoot;

    Console.WriteLine($"Desktop UploadRoot: {desktopUploadsRoot}");
}

// Add services to the container.
builder.Services.AddRazorPages();

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

            // Order matters
            RunFolderWithMariaDb(Path.Combine(dbFolder, "schema", "tables"), mariadbExe);
            RunFolderWithMariaDb(Path.Combine(dbFolder, "schema", "views"), mariadbExe);
            RunFolderWithMariaDb(Path.Combine(dbFolder, "schema", "routines"), mariadbExe);
            RunFolderWithMariaDb(Path.Combine(dbFolder, "schema", "triggers"), mariadbExe);
            RunFolderWithMariaDb(Path.Combine(dbFolder, "schema", "constraints"), mariadbExe);
            RunFolderWithMariaDb(Path.Combine(dbFolder, "schema", "seeds"), mariadbExe);
    
            using var tx = dbConn.BeginTransaction();

            try
            {
                // 1. Record baseline
                using (var cmd = dbConn.CreateCommand())
                {
                    cmd.Transaction = tx;
                    cmd.CommandText = @"
                        INSERT INTO schemaversion (scriptName, appliedAt, checksum)
                        VALUES ('baseline', NOW(), 'baseline');";
                    cmd.ExecuteNonQuery();
                }

                // 2. Mark ALL existing migrations as already applied
                var baselineMigrationsFolder = Path.Combine(dbFolder, "migrations");

                if (Directory.Exists(baselineMigrationsFolder))
                {
                    var files = Directory.GetFiles(baselineMigrationsFolder, "*.sql")
                                        .OrderBy(f => f);

                    foreach (var file in files)
                    {
                        var scriptName = Path.GetFileName(file);
                        var checksum = ComputeChecksum(file);

                        using var cmd = dbConn.CreateCommand();
                        cmd.Transaction = tx;
                        cmd.CommandText = @"
                            INSERT IGNORE INTO schemaversion (scriptName, appliedAt, checksum)
                            VALUES (@name, NOW(), @checksum);";

                        cmd.Parameters.AddWithValue("@name", scriptName);
                        cmd.Parameters.AddWithValue("@checksum", checksum);

                        cmd.ExecuteNonQuery();
                    }
                }

                tx.Commit();
                Console.WriteLine("Finishing first-time setup...");
            }
            catch
            {
                tx.Rollback();
                throw;
            }

        }

        var migrationsFolder = Path.Combine(dbFolder, "migrations");

        if (didBootstrapSchema)
        {
            Console.WriteLine("Your plant database is ready.");
        }
        else
        {
            RunMigrations(migrationsFolder, mariadbExe, dbConn, runtimeRoot);
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

static void RunFolderWithMariaDb(string folderPath, string mariadbExe)
{
    if (!Directory.Exists(folderPath))
    {
        Console.WriteLine($"Folder not found: {folderPath}");
        return;
    }

    var files = Directory.GetFiles(folderPath, "*.sql")
                         .OrderBy(f => f)
                         .ToList();

    foreach (var file in files)
    {
        RunScriptWithMariaDb(file, mariadbExe);
    }
}

static void RunScriptWithMariaDb(string scriptPath, string mariadbExe)
{
    Console.WriteLine($"Setting up database item: {Path.GetFileName(scriptPath)}");

    var process = new Process
    {
        StartInfo = new ProcessStartInfo
        {
            FileName = mariadbExe,
            Arguments = "-u orchid -porchid -P 3308 orchids",
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        }
    };

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

    var sql = File.ReadAllText(scriptPath);

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

    var process = new Process
    {
        StartInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments =
                "-NoProfile -ExecutionPolicy Bypass " +
                $"-File \"{backupScript}\"",
            WorkingDirectory = runtimeRoot,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        }
    };

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

static void RunMigrations(string folderPath, string mariadbExe, MySqlConnection dbConn, string runtimeRoot)
{
    if (!Directory.Exists(folderPath))
    {
        Console.WriteLine($"No migrations folder: {folderPath}");
        return;
    }

    var pendingFiles = new List<string>();

    Console.WriteLine("Checking for database updates...");

    var files = Directory.GetFiles(folderPath, "*.sql")
                         .OrderBy(f => f)
                         .ToList();

    foreach (var file in files)
    {
        var scriptName = Path.GetFileName(file);

        var checksum = ComputeChecksum(file);

        using var checkCmd = dbConn.CreateCommand();
        checkCmd.CommandText = @"
            SELECT checksum 
            FROM schemaversion 
            WHERE scriptName = @name";

        checkCmd.Parameters.AddWithValue("@name", scriptName);

        var existingChecksum = checkCmd.ExecuteScalar() as string;

        if (existingChecksum != null)
        {
            if (!string.Equals(existingChecksum, checksum, StringComparison.OrdinalIgnoreCase))
            {
                throw new Exception(
                    $"Database update check failed for '{scriptName}'. " +
                    $"The update file has changed since it was first applied."
                );
            }

            continue;
        }

        pendingFiles.Add(file);
    }

    if (pendingFiles.Count > 0)
    {
        Console.WriteLine($"Database updates are available: {pendingFiles.Count}");
        RunPreMigrationBackup(runtimeRoot);
    }

    foreach (var file in pendingFiles)
    {
        var scriptName = Path.GetFileName(file);
        var checksum = ComputeChecksum(file);

        Console.WriteLine($"Applying database update: {scriptName}");

        RunScriptWithMariaDb(file, mariadbExe);

        using var insertCmd = dbConn.CreateCommand();
        insertCmd.CommandText = @"
            INSERT INTO schemaversion (scriptName, appliedAt, checksum)
            VALUES (@name, NOW(), @checksum)";

        insertCmd.Parameters.AddWithValue("@name", scriptName);
        insertCmd.Parameters.AddWithValue("@checksum", checksum);

        insertCmd.ExecuteNonQuery();
    }

    if (pendingFiles.Count == 0)
    {
        Console.WriteLine("Database is up to date.");
    }
    else
    {
        VerifyMigrationsApplied(pendingFiles, dbConn);
        Console.WriteLine($"Database updates applied: {pendingFiles.Count}");
    }
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
