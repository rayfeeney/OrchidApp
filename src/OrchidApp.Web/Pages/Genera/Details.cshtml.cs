using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Pages.Genera;

public class DetailsModel : PageModel
{
    public int GenusId { get; private set; }

    public void OnGet(int id)
    {
        GenusId = id;
    }
}
