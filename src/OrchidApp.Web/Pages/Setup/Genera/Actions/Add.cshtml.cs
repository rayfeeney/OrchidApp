using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using OrchidApp.Web.Data;

namespace OrchidApp.Web.Pages.Setup.Genera.Actions;

public class AddModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty, Required]
    [Display(Name = "Genus name")]
    public string GenusName { get; set; } = string.Empty;

    [BindProperty]
    [Display(Name = "Notes")]
    public string? GenusNotes { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        await _db.Database.ExecuteSqlRawAsync(
            "CALL spAddGenus(@p0, @p1);",
            GenusName,
            (object?)GenusNotes ?? DBNull.Value
        );

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage("/Setup/Genera/Index");
    }
}