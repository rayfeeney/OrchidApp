using Microsoft.AspNetCore.Mvc.RazorPages;

namespace OrchidApp.Web.Pages.Legal;

public class LicenceModel : PageModel
{
    private readonly IWebHostEnvironment _env;

    public string OrchidAppLicenceText { get; private set; } = string.Empty;
    public string ThirdPartyNoticesText { get; private set; } = string.Empty;
    public string MariaDbLicenceText { get; private set; } = string.Empty;
    public string MariaDbThirdPartyText { get; private set; } = string.Empty;
    public string LibVipsLicenceText { get; private set; } = string.Empty;

    public LicenceModel(IWebHostEnvironment env)
    {
        _env = env;
    }

    public void OnGet()
    {
        OrchidAppLicenceText = ReadLegalFile("LICENSE");
        ThirdPartyNoticesText = ReadLegalFile("THIRD_PARTY_NOTICES.md");
        MariaDbLicenceText = ReadLegalFile(Path.Combine("mariadb", "COPYING"));
        MariaDbThirdPartyText = ReadLegalFile(Path.Combine("mariadb", "THIRDPARTY"));
        LibVipsLicenceText = ReadLegalFile(Path.Combine("libvips", "LICENSE"));
    }

    private string ReadLegalFile(string relativePath)
    {
        var path = Path.Combine(
            _env.ContentRootPath,
            "Legal",
            relativePath
        );

        if (System.IO.File.Exists(path))
        {
            return System.IO.File.ReadAllText(path);
        }

        return $"Licence file not found: {relativePath}";
    }
}