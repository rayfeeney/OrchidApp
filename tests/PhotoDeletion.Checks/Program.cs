using Microsoft.Extensions.Logging.Abstractions;
using OrchidApp.Web.Services;

var root = Path.Combine(Path.GetTempPath(), "orchid-photo-delete-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(Path.Combine(root, "plants", "1"));
var registry = new PhotoRecoveryRegistry();
PhotoWriteBatch Batch() => new(root, registry, NullLogger<PhotoWriteBatch>.Instance);
void Check(bool ok, string name) { if (!ok) throw new Exception(name); Console.WriteLine("PASS " + name); }
var main = Path.Combine(root, "plants", "1", "photo.jpg");
var thumb = Path.Combine(root, "plants", "1", "photo_thumb.jpg");
var other = Path.Combine(root, "plants", "1", "other.jpg");
void Seed() { File.WriteAllText(main, "main"); File.WriteAllText(thumb, "thumb"); File.WriteAllText(other, "other"); }
bool Journals() => Directory.Exists(Path.Combine(root, ".photo-recovery")) && Directory.EnumerateFiles(Path.Combine(root, ".photo-recovery")).Any();
try
{
    Seed();
    using (var batch = Batch()) { batch.Begin(); batch.TrackDeletion(1, new[] { "photo.jpg", "photo_thumb.jpg" }); batch.BeforeCommit(); batch.RolledBack(); }
    Check(File.ReadAllText(main) == "main" && File.Exists(thumb) && !Journals(), "rollback retains both files and clears journal");
    using (var batch = Batch()) { batch.Begin(); batch.TrackDeletion(1, new[] { "photo.jpg", "photo_thumb.jpg", "photo.jpg" }); batch.BeforeCommit(); batch.Committed(); }
    Check(!File.Exists(main) && !File.Exists(thumb) && File.Exists(other) && !Journals(), "commit deletes only selected pair");
    using (var batch = Batch()) { batch.Begin(); batch.TrackDeletion(1, new[] { "photo.jpg" }); batch.Committed(); }
    Check(!Journals(), "missing file succeeds");
    using (var batch = Batch()) { batch.Begin(); batch.TrackDeletion(2, new[] { "photo.jpg" }); batch.Committed(); Check(!batch.CleanupRequired, "missing plant folder succeeds"); }
    foreach (var name in new[] { "../other.jpg", "..\\other.jpg", "/photo.jpg", "C:\\photo.jpg", "photo.jpg:stream", "photo.jpg/other.jpg", "" })
    {
        bool rejected = false;
        try { PhotoDeletionPaths.Resolve(root, 1, name); } catch (InvalidOperationException) { rejected = true; }
        Check(rejected, "reject unsafe name: " + name);
    }
    Seed();
    using (var batch = Batch()) { batch.Begin(); batch.TrackDeletion(1, new[] { "photo.jpg" }); batch.BeforeCommit(); batch.Retain("CommitOutcomeUnknown"); }
    Check(File.Exists(main) && Journals(), "uncertain commit retains files and recovery evidence");
    using (var batch = Batch())
    {
        batch.Begin(); bool rejected = false;
        try { batch.TrackDeletion(1, new[] { "other.jpg" }); } catch (InvalidOperationException) { rejected = true; }
        Check(rejected, "unresolved recovery blocks deletion");
    }
    foreach (var journal in Directory.EnumerateFiles(Path.Combine(root, ".photo-recovery"))) File.Delete(journal);
    using (var batch = Batch())
    {
        batch.Begin(); batch.TrackDeletion(1, new[] { "photo.jpg", "photo_thumb.jpg" }); batch.BeforeCommit();
        // Cross-platform deterministic cleanup failure, without platform-specific file sharing assumptions.
        File.Delete(thumb); Directory.CreateDirectory(thumb);
        batch.Committed();
        Check(batch.CleanupRequired && Journals() && File.Exists(other), "cleanup failure retains recovery record and unrelated file");
        Directory.Delete(thumb);
    }
    foreach (var journal in Directory.EnumerateFiles(Path.Combine(root, ".photo-recovery"))) File.Delete(journal);
    var link = Path.Combine(root, "plants", "1", "link.jpg");
    try
    {
        File.CreateSymbolicLink(link, other);
        bool rejected = false;
        try { PhotoDeletionPaths.Resolve(root, 1, "link.jpg"); } catch (InvalidOperationException) { rejected = true; }
        Check(rejected && File.Exists(other), "symlink rejected");
        File.Delete(link);
    }
    catch (Exception ex) when (ex is UnauthorizedAccessException || (OperatingSystem.IsWindows() && ex is IOException && (ex.HResult & 0xffff) == 1314))
    { Console.WriteLine("SKIP symlink creation requires Windows developer mode or privilege"); }
}
finally { Directory.Delete(root, recursive: true); }
