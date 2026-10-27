using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NetVips;
using OrchidApp.Web.Services;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using OrchidApp.Web.Configuration;

internal static class PhotoRecoveryChecks
{
    public static async Task RunAsync(string root)
    {
        var registry = new PhotoRecoveryRegistry();
        int count = 0;
        void Check(bool pass, string name) { if (!pass) throw new Exception("Recovery check failed: " + name); count++; }
        var fixtures = Path.Combine(AppContext.BaseDirectory, "fixtures");
        var isolated = Path.Combine(root, "recovery"); Directory.CreateDirectory(isolated);
        var original = Path.Combine(isolated, "existing.jpg"); File.WriteAllText(original, "original bytes");
        var failedPair = new PhotoPipeline(Options.Create(new MediaIngestionOptions()), NullLogger<PhotoPipeline>.Instance,
            publisher: new FailSecondPublish());
        await using (var stream = File.OpenRead(Path.Combine(fixtures, "orientation-1.jpg")))
        {
            bool failed = false;
            try { await failedPair.ProcessAndSaveAsync(stream, new PhotoStorageTarget { EntityType = "test", EntityId = "pair" }, isolated); }
            catch (InvalidOperationException) { failed = true; }
            Check(failed && !Directory.EnumerateFiles(Path.Combine(isolated, "test", "pair")).Any(), "late pair publish failure cleans main/thumbnail/temp");
            Check(File.ReadAllText(original) == "original bytes", "preexisting file preserved");
        }
        foreach (var outcome in new[] { "success", "validation", "exception", "commit-unknown", "rollback-unknown" })
        {
            var folder = Path.Combine(isolated, outcome); Directory.CreateDirectory(folder);
            using var batch = new PhotoWriteBatch(folder, registry, NullLogger<PhotoWriteBatch>.Instance);
            var page = new PageContext { HttpContext = new DefaultHttpContext(), RouteData = new Microsoft.AspNetCore.Routing.RouteData(), ActionDescriptor = new CompiledPageActionDescriptor() };
            var filters = new List<IFilterMetadata>(); var descriptor = new HandlerMethodDescriptor(); var model = new object();
            var context = new PageHandlerExecutingContext(page, filters, descriptor, new Dictionary<string, object?>(), model);
            var transaction = new FaultTransaction(outcome);
            var file = Path.Combine(folder, "main.jpg"); var thumb = Path.Combine(folder, "thumb.jpg");
            bool threw = false;
            try
            {
                await PhotoWriteCompletion.ExecuteAsync(transaction, batch, context, () =>
                {
                    batch.Track(new[] { file, thumb }); File.WriteAllText(file, "new main"); File.WriteAllText(thumb, "new thumb");
                    var executed = new PageHandlerExecutedContext(page, filters, descriptor, model);
                    if (outcome == "exception") executed.Exception = new IOException("injected handler failure");
                    if (outcome is "validation" or "rollback-unknown") context.ModelState.AddModelError("photo", "injected validation failure");
                    executed.Result = outcome is "validation" or "rollback-unknown" ? new PageResult() : new LocalRedirectResult("/Plants");
                    return Task.FromResult(executed);
                });
            }
            catch (IOException) { threw = true; }
            var journals = Directory.GetFiles(Path.Combine(folder, ".photo-recovery"), "*.json");
            bool uncertain = outcome.EndsWith("unknown", StringComparison.Ordinal);
            Check(File.Exists(file) == (uncertain || outcome == "success"), outcome + " main file decision");
            Check(File.Exists(thumb) == (uncertain || outcome == "success"), outcome + " thumbnail decision");
            Check(journals.Length == (uncertain ? 1 : 0), outcome + " durable recovery decision");
            Check(transaction.CommitCalls == (outcome is "success" or "commit-unknown" ? 1 : 0), outcome + " commit decision");
            if (uncertain)
            {
                using var journal = JsonDocument.Parse(File.ReadAllText(journals[0]));
                Check(journal.RootElement.GetProperty("state").GetString() == (outcome == "commit-unknown" ? "CommitOutcomeUnknown" : "RollbackOutcomeUnknown"), outcome + " state");
                Check(!registry.IsActive(journals[0]), outcome + " readiness can detect journal");
            }
            if (outcome == "commit-unknown") Check(threw, "commit error is not hidden");
        }
        var readiness = new ReadinessProbe(new ConfigurationBuilder().Build(),
            Options.Create(new StorageSettings { UploadRoot = isolated }), new MissingNative(), registry, NullLogger<ReadinessProbe>.Instance);
        var unavailable = await readiness.CheckAsync(CancellationToken.None);
        Check(!unavailable.Ready && !unavailable.Checks["nativePhotos"] && unavailable.Checks["uploadRoot"], "missing native dependency is observable without failing the health response");
        Check(!unavailable.Checks["database"], "missing configuration never probes a default database target");
        var blockedRoot = Path.Combine(isolated, "blocked-cleanup"); Directory.CreateDirectory(blockedRoot);
        var blocked = Path.Combine(blockedRoot, "blocked.jpg"); var removable = Path.Combine(blockedRoot, "removable.jpg");
        using (var batch = new PhotoWriteBatch(blockedRoot, registry, NullLogger<PhotoWriteBatch>.Instance))
        {
            batch.Begin(); batch.Track(new[] { blocked, removable });
            Directory.CreateDirectory(blocked); File.WriteAllText(removable, "new file");
            batch.RolledBack();
            Check(Directory.Exists(blocked), "failed cleanup target is retained for review");
            Check(!File.Exists(removable), "cleanup continues for other owned files");
            var journal = Directory.GetFiles(Path.Combine(blockedRoot, ".photo-recovery"), "*.json").Single();
            Check(File.ReadAllText(journal).Contains("RollbackCleanupRequired") && !registry.IsActive(journal), "cleanup failure is durable and observable");
        }
        Console.WriteLine($"{count} photo pair/transaction recovery checks passed.");
    }

    private sealed class FailSecondPublish : PhotoFilePublisher
    {
        private int calls;
        public override void Publish(string source, string destination)
        {
            if (++calls == 2) throw new IOException("Injected thumbnail publish failure");
            base.Publish(source, destination);
        }
    }
    private sealed class MissingNative : IPhotoNativeProbe
    {
        public Task<bool> CheckAsync(string root, CancellationToken ct) => throw new DllNotFoundException("Injected absent native runtime");
    }
    private sealed class FaultTransaction(string outcome) : IDbContextTransaction
    {
        public Guid TransactionId { get; } = Guid.NewGuid();
        public int CommitCalls { get; private set; }
        public void Commit() => CommitAsync().GetAwaiter().GetResult();
        public Task CommitAsync(CancellationToken cancellationToken = default)
        { CommitCalls++; return outcome == "commit-unknown" ? Task.FromException(new IOException("Injected uncertain commit")) : Task.CompletedTask; }
        public void Rollback() => RollbackAsync().GetAwaiter().GetResult();
        public Task RollbackAsync(CancellationToken cancellationToken = default) => outcome == "rollback-unknown" ? Task.FromException(new IOException("Injected unknown rollback")) : Task.CompletedTask;
        public void Dispose() { }
        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }
}
