using System.Text.Json;
using OrchidApp.Launcher;
using OrchidApp.Launcher.Infrastructure;

internal static class MigrationChecks
{
    public static bool TryRunCommand(string[] args)
    {
        if (args.Length >= 4 && args[0] == "migrate-reconciled")
        {
            var paths = new WindowsProgramDataPaths(args[2]);
            var coordinator = new LegacyMigrationCoordinator(paths, args.Length == 5 ? _ => throw new IOException("Intentional copy interruption") : null);
            using var held = coordinator.AcquireLock();
            using var receipt = JsonDocument.Parse(File.ReadAllText(Path.Combine(args[1], "source-capture.json")));
            var state = coordinator.Begin(receipt.RootElement.GetProperty("originalRoot").GetString()!, args[1], args[3]);
            coordinator.ContinueCopy(state);
            return true;
        }
        if (args.Length == 2 && args[0] is "resume-migration" or "complete-migration" or "migration-layout" or "fail-migration-readiness")
        {
            var paths = new WindowsProgramDataPaths(args[1]);
            var state = new MigrationStateService(paths).Load()!;
            var coordinator = new LegacyMigrationCoordinator(paths);
            using var held = coordinator.AcquireLock();
            if (args[0] == "resume-migration") coordinator.ContinueCopy(state);
            else if (args[0] == "complete-migration") coordinator.CompleteAfterReadiness(state);
            else if (args[0] == "fail-migration-readiness")
            {
                state.MigrationStatus=MigrationStatus.Failed;state.FailedAtUtc=DateTime.UtcNow;state.ErrorMessage="Disposable MariaDB startup failure";
                new MigrationStateService(paths).Save(state);
            }
            else Console.WriteLine(OrchidAppLayoutResolver.Resolve(Path.Combine(paths.Root,"installed"), paths, new[] { state.SourceLegacyRootPath }).Status);
            return true;
        }
        return false;
    }

    public static int Run(string parent)
    {
        var count=0;
        void Check(string name, bool pass) { if (!pass) throw new Exception(name); count++; }
        void Reject(string name, Action action)
        {
            try { action(); } catch (Exception e) when (e is InvalidOperationException or IOException or JsonException) { count++; return; }
            throw new Exception("Did not reject: " + name);
        }
        (string source, WindowsProgramDataPaths paths, string snapshot, string backup, MigrationState state) Fixture()
        {
            var root=Path.Combine(parent, "reconcile-"+Guid.NewGuid().ToString("N"));
            var source=Path.Combine(root,"original");
            Directory.CreateDirectory(Path.Combine(source,"data/mariadb/orchids"));
            File.WriteAllText(Path.Combine(source,"data/mariadb/orchids/fixture.ibd"),"database");
            Directory.CreateDirectory(Path.Combine(source,"data/mariadb/mysql"));
            File.WriteAllText(Path.Combine(source,"data/mariadb/mysql/system.ibd"),"system");
            Directory.CreateDirectory(Path.Combine(source,"wwwroot/uploads/plants/1"));
            File.WriteAllText(Path.Combine(source,"wwwroot/uploads/plants/1/photo.jpg"),"photo");
            File.WriteAllText(Path.Combine(source,"launcher-settings.json"),"{}");
            var paths=new WindowsProgramDataPaths(Path.Combine(root,"pd"));
            Directory.CreateDirectory(paths.MariaDbData); Directory.CreateDirectory(paths.Uploads);
            var snapshot=LegacySourceSnapshot.Capture(source,Path.Combine(paths.Root,"migration-staging"));
            var backup=Path.Combine(root,"verified-backup.zip"); File.WriteAllText(backup,"fixture backup gate");
            var state=new LegacyMigrationCoordinator(paths).Begin(source,snapshot,backup);
            return (source,paths,snapshot,backup,state);
        }
        var f=Fixture();
        var states=new MigrationStateService(f.paths);
        var originalFingerprint=MigrationFiles.Fingerprint(f.source);
        Check("Begin persists version 2 copying ownership", states.Load()!.SchemaVersion==2 && states.Load()!.Phase==LegacyMigrationCoordinator.Copying);
        using (var held=new LegacyMigrationCoordinator(f.paths).AcquireLock())
            Reject("Second migration cannot acquire operation lock",()=>new LegacyMigrationCoordinator(f.paths).AcquireLock());
        var interrupted=new LegacyMigrationCoordinator(f.paths, point => { if(point=="CopiedFile") throw new IOException("interrupted"); });
        Reject("Interrupted file copy reported",()=>interrupted.ContinueCopy(f.state));
        Check("Interrupted copy does not claim completion",states.Load()!.Phase==LegacyMigrationCoordinator.Copying && states.Load()!.MigrationCompletedAtUtc is null);
        Check("Original source preserved during interruption",MigrationFiles.Fingerprint(f.source)==originalFingerprint);
        var coordinator=new LegacyMigrationCoordinator(f.paths);
        coordinator.ContinueCopy(states.Load()!);
        var awaiting=states.Load()!;
        Check("Resumed copy awaits readiness",awaiting.Phase==LegacyMigrationCoordinator.AwaitingReadiness && awaiting.MigrationStatus!=MigrationStatus.Completed);
        Check("Resumed photo/settings exact",File.ReadAllText(Path.Combine(f.paths.Uploads,"plants/1/photo.jpg"))=="photo" && File.ReadAllText(f.paths.LauncherSettingsFile)=="{}");
        awaiting.MigrationStatus=MigrationStatus.Failed;awaiting.ErrorMessage="Database did not start";states.Save(awaiting);
        File.WriteAllText(Path.Combine(f.paths.MariaDbData,"orchids/fixture.ibd"),"database startup changed raw bytes");
        coordinator.ContinueCopy(states.Load()!);
        Check("Readiness retry never recopies raw DB",File.ReadAllText(Path.Combine(f.paths.MariaDbData,"orchids/fixture.ibd"))=="database startup changed raw bytes");
        Check("Readiness failure survives new launch",states.Load()!.MigrationStatus==MigrationStatus.Failed);
        coordinator.CompleteAfterReadiness(states.Load()!);
        Check("Readiness completion persisted",states.Load()!.MigrationStatus==MigrationStatus.Completed && states.Load()!.MigrationCompletedAtUtc is not null);
        var layout=OrchidAppLayoutResolver.Resolve(Path.Combine(f.paths.Root,"installed"),f.paths,new[]{f.source});
        Check("Verified target outranks exact retained original",layout.Status==OrchidAppLayoutStatus.ProgramDataLayoutInPlace);
        var other=Fixture();
        Check("Unrelated source remains ambiguous",OrchidAppLayoutResolver.Resolve(f.source,f.paths,new[]{other.source}).Status==OrchidAppLayoutStatus.LegacyAndProgramDataFound);
        File.WriteAllText(Path.Combine(f.source,"launcher-settings.json"),"changed");
        Reject("Changed retained source blocks precedence",()=>OrchidAppLayoutResolver.Resolve(f.source,f.paths,Array.Empty<string>()));
        File.WriteAllText(Path.Combine(f.source,"launcher-settings.json"),"{}");
        File.WriteAllText(Path.Combine(f.paths.Root,"migration-target-id"),"different ownership");
        Reject("Changed target identity blocks precedence",()=>coordinator.Validate(states.Load()!));

        var partial=Fixture(); var ps=new MigrationStateService(partial.paths);
        Reject("Partial copy fixture",()=>new LegacyMigrationCoordinator(partial.paths,_=>throw new IOException("interrupt")).ContinueCopy(partial.state));
        var witness=Path.Combine(partial.paths.MariaDbData,"unrelated.bin"); File.WriteAllText(witness,"keep");
        Reject("Unowned partial destination never overwritten",()=>new LegacyMigrationCoordinator(partial.paths).ContinueCopy(ps.Load()!));
        Check("Unowned bytes retained",File.ReadAllText(witness)=="keep");
        File.Delete(witness);
        var owned=MigrationFiles.Inventory(partial.paths.Root,false).First(e=>!e.IsDirectory);
        var ownedFile=Path.Combine(partial.paths.Root,owned.Path);var ownedBytes=File.ReadAllBytes(ownedFile);
        File.WriteAllText(ownedFile,"changed by another writer");
        Reject("Changed owned partial file cannot be overwritten",()=>new LegacyMigrationCoordinator(partial.paths).ContinueCopy(ps.Load()!));
        Check("Changed partial bytes retained",File.ReadAllText(ownedFile)=="changed by another writer");
        File.WriteAllBytes(ownedFile,ownedBytes);
        File.Delete(Path.Combine(partial.paths.Root,"migration-target-id"));
        Reject("Missing ownership with partial data stops",()=>new LegacyMigrationCoordinator(partial.paths).ContinueCopy(ps.Load()!));

        var full=Fixture(); var fs=new MigrationStateService(full.paths);
        Reject("State commit interruption after full copy",()=>new LegacyMigrationCoordinator(full.paths,p=>{if(p=="BeforeReadinessState")throw new IOException("state commit interrupted");}).ContinueCopy(full.state));
        Check("Failed phase save leaves atomic prior copying state",fs.Load()!.Phase==LegacyMigrationCoordinator.Copying);
        new LegacyMigrationCoordinator(full.paths).ContinueCopy(fs.Load()!);
        Check("Full matching copy can reconcile without overwrite",fs.Load()!.Phase==LegacyMigrationCoordinator.AwaitingReadiness);
        var stateBefore=File.ReadAllBytes(full.paths.MigrationStateFile);
        using (var held=new FileStream(full.paths.MigrationStateFile,FileMode.Open,FileAccess.Read,FileShare.Read))
        {
            var loaded=fs.Load()!;
            Reject("Locked completion state cannot be committed",()=>new LegacyMigrationCoordinator(full.paths).CompleteAfterReadiness(loaded));
            Check("Failed completion commit retains readiness phase in memory",loaded.Phase==LegacyMigrationCoordinator.AwaitingReadiness);
            Check("Failed atomic save retains previous valid JSON",File.ReadAllBytes(full.paths.MigrationStateFile).SequenceEqual(stateBefore));
        }
        var bad=Fixture();var bs=new MigrationStateService(bad.paths);
        var corrupt=bs.Load()!;corrupt.CopyManifest![0].Path="../outside";bs.Save(corrupt);
        Reject("Manifest path escape rejected",()=>new LegacyMigrationCoordinator(bad.paths).Validate(bs.Load()!));
        File.WriteAllText(bad.paths.MigrationStateFile,"");Reject("Empty state cannot become new install",()=>bs.Load());
        File.WriteAllText(bad.paths.MigrationStateFile,"broken");Reject("Corrupt state cannot become new install",()=>bs.Load());
        bs.Save(new MigrationState {SchemaVersion=1,MigrationStatus=MigrationStatus.Completed});
        Reject("Old completion without readiness requires review",()=>OrchidAppLayoutResolver.Resolve(bad.source,bad.paths,Array.Empty<string>()));
        var missing=Fixture();File.Delete(missing.backup);
        Reject("Missing safety backup blocks copy resume",()=>new LegacyMigrationCoordinator(missing.paths).ContinueCopy(missing.state));
        var changed=Fixture();File.WriteAllText(Path.Combine(changed.snapshot,"launcher-settings.json"),"changed capture");
        Reject("Changed capture blocks resume",()=>new LegacyMigrationCoordinator(changed.paths).ContinueCopy(changed.state));
        var system=Fixture();File.Delete(system.paths.MigrationStateFile);
        Directory.CreateDirectory(Path.Combine(system.paths.MariaDbData,"mysql"));
        File.WriteAllText(Path.Combine(system.paths.MariaDbData,"mysql/residual.ibd"),"residual");
        Reject("Residual system database blocks new migration",()=>new LegacyMigrationCoordinator(system.paths).Begin(system.source,system.snapshot,system.backup));
        var noProof=Fixture();new LegacyMigrationCoordinator(noProof.paths).ContinueCopy(noProof.state);
        File.Delete(noProof.paths.MigrationStateFile);
        Check("Target plus source without completion proof remains ambiguous",OrchidAppLayoutResolver.Resolve(noProof.source,noProof.paths,Array.Empty<string>()).Status==OrchidAppLayoutStatus.LegacyAndProgramDataFound);
        return count;
    }
}
