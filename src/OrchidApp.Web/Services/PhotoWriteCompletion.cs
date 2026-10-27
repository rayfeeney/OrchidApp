using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore.Storage;
using OrchidApp.Web.Infrastructure;

namespace OrchidApp.Web.Services;

public static class PhotoSchemaContract
{
    public static bool IsReady(IReadOnlyDictionary<string, string> history)
    {
        var cutoff = MigrationHistory.Cutoff(history);
        return (cutoff is not null && string.CompareOrdinal(cutoff, "202610271200") >= 0) ||
            (history.TryGetValue("202610271200_PhotoTaxonTransaction.sql", out var checksum) &&
             checksum.Equals("b736d92b502c47cd30cc44d08eec89122196d2340d481a444202116cb1d81686", StringComparison.OrdinalIgnoreCase));
    }
}

public static class PhotoWriteCompletion
{
    public static async Task ExecuteAsync(IDbContextTransaction transaction, PhotoWriteBatch batch,
        PageHandlerExecutingContext context, PageHandlerExecutionDelegate next)
    {
        batch.Begin();
        bool commitAttempted = false;
        try
        {
            var executed = await next();
            if (executed.Exception is null && context.ModelState.IsValid &&
                executed.Result is RedirectToPageResult or LocalRedirectResult)
            {
                batch.BeforeCommit();
                commitAttempted = true;
                await transaction.CommitAsync(context.HttpContext.RequestAborted);
                batch.Committed();
            }
            else
            {
                await transaction.RollbackAsync(CancellationToken.None);
                batch.RolledBack();
            }
        }
        catch (Exception ex)
        {
            if (commitAttempted) batch.Retain("CommitOutcomeUnknown", ex);
            else
            {
                try { await transaction.RollbackAsync(CancellationToken.None); batch.RolledBack(); }
                catch (Exception rollback) { batch.Retain("RollbackOutcomeUnknown", rollback); }
            }
            throw;
        }
    }
}
