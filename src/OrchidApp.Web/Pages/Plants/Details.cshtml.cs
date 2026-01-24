using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Pages.Plants;

public class DetailsModel : PageModel
{
    public int PlantId { get; private set; }

    public void OnGet(int id)
    {
        PlantId = id;
    }
}
