using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.ComponentModel.DataAnnotations;
using OrchidApp.Web.Infrastructure;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Genera.Actions;

public class AddModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly IStoredProcedureExecutor _sp;

    public AddModel(IStoredProcedureExecutor sp)
    {
        _sp = sp;
    }

    [BindProperty, Required]
    [Display(Name = "Genus name")]
    public string GenusName { get; set; } = string.Empty;

    [BindProperty]
    [Display(Name = "Notes")]
    public string? GenusNotes { get; set; }

    public IActionResult OnGet()
    {
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        var result = await _sp.QuerySingleAsync<AddGenusResult>(
            "spAddGenus",
            new StoredProcedureParameter("pGenusName", GenusName),
            new StoredProcedureParameter("pGenusNotes", GenusNotes)
        );

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage("/Setup/Genera/Details", new { id = result.GenusId });
    }
}