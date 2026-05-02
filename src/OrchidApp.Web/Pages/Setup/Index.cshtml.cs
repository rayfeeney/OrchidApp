using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Pages.Setup
{
    public class IndexModel : PageModel
    {
        [BindProperty(SupportsGet = true)]
        public string? ReturnUrl { get; set; }
        
        public void OnGet()
        {
        }
    }
}
