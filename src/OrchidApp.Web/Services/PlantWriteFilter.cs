using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;

namespace OrchidApp.Web.Services;

// Hold the same parent-row lock as the structural procedures until the entire
// handler finishes. Reads deliberately remain outside this transaction.
public sealed class PlantWriteFilter(OrchidDbContext db, PhotoWriteBatch batch) : IAsyncPageFilter
{
    private static readonly HashSet<string> Pages = new(StringComparer.Ordinal)
    {
        "/Plants/Edit/Index", "/Plants/Events/Add", "/Plants/Events/Edit",
        "/Plants/Events/Remove", "/Plants/Events/Split", "/Plants/Events/Propagate",
        "/Plants/Photos/Index"
    };

    public Task OnPageHandlerSelectionAsync(PageHandlerSelectedContext context) => Task.CompletedTask;

    public async Task OnPageHandlerExecutionAsync(PageHandlerExecutingContext context, PageHandlerExecutionDelegate next)
    {
        var page = (context.ActionDescriptor as PageActionDescriptor)?.ViewEnginePath;
        if (!HttpMethods.IsPost(context.HttpContext.Request.Method) || page is null || !Pages.Contains(page))
        {
            await next();
            return;
        }

        if (!int.TryParse(context.RouteData.Values["plantId"]?.ToString(), out var plantId))
        {
            context.Result = new BadRequestResult();
            return;
        }
        var request = context.HttpContext.Request;
        var suppliedIds = request.Query["plantId"].ToArray().AsEnumerable();
        if (request.HasFormContentType)
            suppliedIds = suppliedIds.Concat((await request.ReadFormAsync(request.HttpContext.RequestAborted))["plantId"].ToArray());
        if (suppliedIds.Any(value => !int.TryParse(value, out var suppliedId) || suppliedId != plantId))
        {
            context.Result = new BadRequestResult();
            return;
        }
        // Lock exactly the plant that the bound handler will write, including
        // attempts to override its route ID through a form or query string.
        var property = context.HandlerInstance.GetType().GetProperty("PlantId");
        var boundId = property?.SetMethod?.IsPublic == true ? property.GetValue(context.HandlerInstance) : null;
        if ((boundId is int modelId && modelId != plantId) ||
            (context.HandlerArguments.TryGetValue("plantId", out var argument) && !Equals(argument, plantId)))
        {
            context.Result = new BadRequestResult();
            return;
        }

        var ct = context.HttpContext.RequestAborted;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        // FromSql + materialization avoids composing LINQ over the locking query.
        var plants = await db.Plants.FromSqlInterpolated($"SELECT * FROM plant WHERE plantId = {plantId} FOR UPDATE")
            .AsNoTracking().ToListAsync(ct);
        if (plants.Count == 0)
        {
            context.Result = new NotFoundResult();
            return;
        }
        if (plants[0].EndDate is not null)
        {
            context.Result = new BadRequestObjectResult("Ended plants are read-only.");
            return;
        }

        await PhotoWriteCompletion.ExecuteAsync(transaction, batch, context, next);
    }
}
