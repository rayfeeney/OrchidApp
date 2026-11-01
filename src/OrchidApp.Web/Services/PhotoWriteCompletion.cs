using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.RazorPages;
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
        bool rollbackUnknown = false;
        PageHandlerExecutedContext? executed = null;
        try
        {
            executed = await next();
            if (executed.Exception is null && context.ModelState.IsValid &&
                executed.Result is RedirectToPageResult or LocalRedirectResult)
            {
                batch.BeforeCommit();
                commitAttempted = true;
                await transaction.CommitAsync(context.HttpContext.RequestAborted);
                batch.Committed();
                if (batch.HasDeletions && context.HandlerInstance is PageModel page)
                    page.TempData["PhotoMessage"] = batch.CleanupRequired
                        ? "Photo removed from the gallery, but file cleanup requires recovery review. See the application log."
                        : "Photo deleted.";
            }
            else
            {
                await transaction.RollbackAsync(CancellationToken.None);
                batch.RolledBack();
                if (batch.HasDeletions && executed.Exception is not null && context.HandlerInstance is Pages.Plants.Photos.IndexModel failedPage)
                {
                    batch.LogDeletionFailure(executed.Exception);
                    failedPage.TempData["PhotoMessage"] = "The photo could not be deleted. No photo files were removed. Please try again.";
                    executed.ExceptionHandled = true;
                    executed.Result = new RedirectToPageResult(null, new { plantId = context.RouteData.Values["plantId"], returnUrl = failedPage.ReturnUrl });
                }
            }
        }
        catch (Exception ex)
        {
            if (batch.HasDeletions) batch.LogDeletionFailure(ex);
            if (commitAttempted) batch.Retain("CommitOutcomeUnknown", ex);
            else
            {
                try { await transaction.RollbackAsync(CancellationToken.None); batch.RolledBack(); }
                catch (Exception rollback) { rollbackUnknown = true; batch.Retain("RollbackOutcomeUnknown", rollback); }
            }
            if (batch.HasDeletions && context.HandlerInstance is Pages.Plants.Photos.IndexModel page)
            {
                page.TempData["PhotoMessage"] = commitAttempted || rollbackUnknown
                    ? "The deletion outcome could not be confirmed. Files have been retained for recovery review. Do not retry until reviewed."
                    : "The photo could not be deleted. Please try again.";
                var result = new RedirectToPageResult(null, new { plantId = context.RouteData.Values["plantId"], returnUrl = page.ReturnUrl });
                if (executed is not null)
                {
                    executed.ExceptionHandled = true;
                    executed.Result = result;
                }
                else context.Result = result;
                return;
            }
            throw;
        }
    }
}
