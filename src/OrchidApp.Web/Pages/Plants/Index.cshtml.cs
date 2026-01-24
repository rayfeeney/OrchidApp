using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Pages.Plants;

public class IndexModel : PageModel
{
    public List<string> Plants { get; private set; } = [];

    public void OnGet()
    {
        Plants =
        [
            "Phalaenopsis",
            "Cattleya",
            "Dendrobium"
        ];
    }
}
