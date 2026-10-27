using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Infrastructure;
using MySqlConnector;

namespace OrchidApp.Web.Services;

public sealed class TaxonWriteFilter(OrchidDbContext db, PhotoWriteBatch batch) : IAsyncPageFilter
{
    public Task OnPageHandlerSelectionAsync(PageHandlerSelectedContext context) => Task.CompletedTask;
    public async Task OnPageHandlerExecutionAsync(PageHandlerExecutingContext context, PageHandlerExecutionDelegate next)
    {
        var page = (context.ActionDescriptor as PageActionDescriptor)?.ViewEnginePath;
        if (!HttpMethods.IsPost(context.HttpContext.Request.Method) ||
            page is not ("/Setup/Taxa/Actions/Add" or "/Setup/Taxa/Actions/Edit"))
        { await next(); return; }
        try
        {
            await db.Database.OpenConnectionAsync(context.HttpContext.RequestAborted);
            if (!PhotoSchemaContract.IsReady(SchemaBaseline.ReadHistory((MySqlConnection)db.Database.GetDbConnection())))
            {
                context.Result = new ObjectResult("A database update is required before saving species/hybrid details or photos.") { StatusCode = 503 };
                return;
            }
        }
        catch (InvalidOperationException)
        {
            context.Result = new ObjectResult("Database migration state requires review before saving.") { StatusCode = 503 };
            return;
        }
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, context.HttpContext.RequestAborted);
        if (page.EndsWith("/Edit", StringComparison.Ordinal))
        {
            if (!int.TryParse(context.RouteData.Values["id"]?.ToString(), out var id))
            { context.Result = new BadRequestResult(); return; }
            var rows = await db.Taxa.FromSqlInterpolated($"SELECT * FROM taxon WHERE taxonId={id} FOR UPDATE")
                .AsNoTracking().ToListAsync(context.HttpContext.RequestAborted);
            if (rows.Count == 0) { context.Result = new NotFoundResult(); return; }
        }
        await PhotoWriteCompletion.ExecuteAsync(tx, batch, context, next);
    }
}
