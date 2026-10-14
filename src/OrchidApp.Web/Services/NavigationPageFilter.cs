using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Services;

// Runs after binding, and again before rendering, for both GET and failed POST.
// Every ReturnUrl property therefore has a validated, explicit local fallback.
public sealed class NavigationPageFilter : IPageFilter
{
    public void OnPageHandlerSelected(PageHandlerSelectedContext context) { }
    public void OnPageHandlerExecuting(PageHandlerExecutingContext context) => Normalize(context.HandlerInstance, context);
    public void OnPageHandlerExecuted(PageHandlerExecutedContext context) => Normalize(context.HandlerInstance, context);

    private static void Normalize(object model, ActionContext context)
    {
        var property = model.GetType().GetProperty("ReturnUrl");
        if (property?.PropertyType != typeof(string) || property.SetMethod?.IsPublic != true) return;
        var page = (context.ActionDescriptor as PageActionDescriptor)?.ViewEnginePath ?? "/Index";
        var fallback = context.HttpContext.Request.PathBase + AppNavigation.Fallback(page, context.RouteData.Values);
        var current = context.HttpContext.Request.PathBase + context.HttpContext.Request.Path;
        property.SetValue(model, AppNavigation.Back(property.GetValue(model) as string, fallback, current));
        context.ModelState.Remove("ReturnUrl");
    }
}
