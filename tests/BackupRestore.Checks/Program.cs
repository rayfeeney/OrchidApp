using OrchidApp.Launcher.Infrastructure;

if (MigrationChecks.TryRunCommand(args)) return;

if (args.Length == 3 && args[0] == "capture") { Console.WriteLine(LegacySourceSnapshot.Capture(args[1], args[2])); return; }
if (args.Length == 3 && args[0] == "migrate") { new LegacyDataMigrationService(new WindowsProgramDataPaths(args[2])).MigrateFromLegacyRoot(args[1]); return; }
var root = Path.Combine(Path.GetTempPath(), "orchids-source-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
var count=0;
void Check(string name, bool ok) { if (!ok) throw new Exception(name); count++; }
void Reject(string name, Action action) { try { action(); } catch (InvalidOperationException) { count++; return; } throw new Exception("Did not reject: " + name); }
try
{
    var source=Path.Combine(root,"legacy source");
    var db=Path.Combine(source,"data","mariadb","orchids"); Directory.CreateDirectory(db);
    File.WriteAllText(Path.Combine(db,"fixture.ibd"),"database bytes");
    var photo=Path.Combine(source,"wwwroot","uploads","plants","1"); Directory.CreateDirectory(photo);
    File.WriteAllText(Path.Combine(photo,"photo.jpg"),"photo bytes");
    File.WriteAllText(Path.Combine(source,"launcher-settings.json"),"{\"CloudBackupFolder\":\"fixture\"}");
    var capture=LegacySourceSnapshot.Capture(source,Path.Combine(root,"staging"));
    Check("Separate source captured", capture != source && File.ReadAllText(Path.Combine(capture,"data","mariadb","orchids","fixture.ibd"))=="database bytes");
    Check("Photo captured",File.ReadAllText(Path.Combine(capture,"wwwroot","uploads","plants","1","photo.jpg"))=="photo bytes");
    Check("Settings captured",File.ReadAllText(Path.Combine(capture,"launcher-settings.json"))==File.ReadAllText(Path.Combine(source,"launcher-settings.json")));
    Check("Source receipt records original",File.ReadAllText(Path.Combine(capture,"source-capture.json")).Contains("originalRoot"));
    Reject("Staging inside source",()=>LegacySourceSnapshot.Capture(source,Path.Combine(source,"staging")));
    using (var writer=new FileStream(Path.Combine(db,"fixture.ibd"),FileMode.Open,FileAccess.Write,FileShare.ReadWrite))
        Reject("Concurrent source writer blocks capture",()=>LegacySourceSnapshot.Capture(source,Path.Combine(root,"busy")));
    Check("Busy capture leaves original unchanged",File.ReadAllText(Path.Combine(db,"fixture.ibd"))=="database bytes");
    File.WriteAllText(Path.Combine(photo,"photo.jpg"),"later change");
    Check("Later original changes cannot alter captured photos",File.ReadAllText(Path.Combine(capture,"wwwroot","uploads","plants","1","photo.jpg"))=="photo bytes");
    var target=new WindowsProgramDataPaths(Path.Combine(root,"target"));
    new LegacyDataMigrationService(target).MigrateFromLegacyRoot(capture);
    Check("Migration uses captured DB",File.ReadAllText(Path.Combine(target.MariaDbData,"orchids","fixture.ibd"))=="database bytes");
    Check("Migration uses captured photos",File.ReadAllText(Path.Combine(target.Uploads,"plants","1","photo.jpg"))=="photo bytes");
    Check("Migration uses captured settings",File.Exists(target.LauncherSettingsFile));
    Reject("Existing target not overwritten",()=>new LegacyDataMigrationService(target).MigrateFromLegacyRoot(capture));
    Reject("Absent source not captured",()=>LegacySourceSnapshot.Capture(Path.Combine(root,"absent"),Path.Combine(root,"staging")));
    var recoveryRoot = Path.Combine(root, "recovery policy");
    Directory.CreateDirectory(recoveryRoot);
    var recovery = new RestoreRecovery(recoveryRoot);
    var cloud = Path.Combine(root, "cloud", "OrchidAppDataBackup.zip");
    Check("No recovery permits ordinary cloud destination", !recovery.IsPending && !recovery.ProtectsCloudDestination(cloud));
    var history = Path.Combine(recoveryRoot, "restore-recovery", "attempt");
    Directory.CreateDirectory(history);
    var record = System.Text.Json.JsonSerializer.Serialize(new {phase="ReplacingSettings",originalInput=cloud,preservedInput=Path.Combine(history,"recovery-input.zip"),safetyBackup=Path.Combine(history,"safety.zip")});
    File.WriteAllText(Path.Combine(history,"recovery.json"), record);
    Check("Completed history protects original cloud input", recovery.ProtectsCloudDestination(cloud));
    Check("History permits separate cloud folder", !recovery.ProtectsCloudDestination(Path.Combine(root,"other cloud","OrchidAppDataBackup.zip")));
    File.WriteAllText(recovery.PendingPath, record);
    Check("Pending marker survives new launcher policy instance", new RestoreRecovery(recoveryRoot).IsPending);
    Check("Pending restore blocks every cloud destination", recovery.ProtectsCloudDestination(Path.Combine(root,"other.zip")));
    Check("Recovery description includes phase and input", recovery.DescribePending().Contains("ReplacingSettings") && recovery.DescribePending().Contains("recovery-input.zip"));
    File.Delete(recovery.PendingPath);
    Check("Completing restore retains cloud protection", recovery.ProtectsCloudDestination(cloud));
    var preflightRecord = System.Text.Json.JsonSerializer.Serialize(new {phase="CreatingSafetyBackup", originalInput=cloud, preservedInput=Path.Combine(history,"recovery-input.zip"), safetyBackup=(string?)null});
    File.WriteAllText(Path.Combine(history,"recovery.json"), preflightRecord);
    Check("Safety-copy failure still protects selected input", recovery.ProtectsCloudDestination(cloud));
    Check("Preflight without a safety ZIP permits separate cloud destination", !recovery.ProtectsCloudDestination(Path.Combine(root,"other.zip")));
    File.WriteAllText(Path.Combine(history,"recovery.json"), "broken");
    try { recovery.ProtectsCloudDestination(cloud); throw new Exception("Corrupt history allowed cloud overwrite"); }
    catch (System.Text.Json.JsonException) { count++; }
    count += MigrationChecks.Run(root);
    Console.WriteLine($"{count} source, restore recovery and migration reconciliation checks passed.");
}
finally { Directory.Delete(root,true); }
