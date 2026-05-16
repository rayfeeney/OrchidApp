using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Reflection;

namespace OrchidApp.Web.Pages;

public class AboutModel : PageModel
{
    public string Version => "1.1.0";
}