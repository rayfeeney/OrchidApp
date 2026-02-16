using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Pages.Legal;

public class LicenceModel : PageModel
{
    private readonly IWebHostEnvironment _env;

    public string LicenceText { get; private set; } = string.Empty;

    public LicenceModel(IWebHostEnvironment env)
    {
        _env = env;
    }

    public void OnGet()
    {
        var licencePath = Path.Combine(_env.ContentRootPath, "LICENSE");

        if (System.IO.File.Exists(licencePath))
        {
            LicenceText = System.IO.File.ReadAllText(licencePath);
        }
        else
        {
            LicenceText = "Licence file not found.";
        }
    }

}
