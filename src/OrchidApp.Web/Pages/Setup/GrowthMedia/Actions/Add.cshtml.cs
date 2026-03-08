using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.GrowthMedia.Actions;

public class AddModel : PageModel
{
    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty]
    public GrowthMedium Input { get; set; } = new();

    public IActionResult OnGet()
    {
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        Input.IsActive = true;

        _db.GrowthMedia.Add(Input);
        await _db.SaveChangesAsync();

        return RedirectToPage("/Setup/GrowthMedia/Details",
            new { growthMediumId = Input.GrowthMediumId });
    }
}