using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Reflection;

namespace OrchidApp.Web.Pages;

public class AboutModel : PageModel
{
    public string Version =>
        Assembly
            .GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion
            .Split('+')[0]
        ?? "Unknown";
}