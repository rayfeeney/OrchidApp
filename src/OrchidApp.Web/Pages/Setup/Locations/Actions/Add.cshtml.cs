using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Infrastructure;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Setup.Locations.Actions;

public class AddModel : PageModel
{
    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public class InputModel
    {
        [Required]
        [Display(Name = "Location name")]
        public string LocationName { get; set; } = "";

        [Display(Name = "Location type")]
        public string? LocationTypeCode { get; set; }

        [Display(Name = "Location notes")]
        public string? LocationNotes { get; set; }

        [Display(Name = "Climate")]
        public string? ClimateCode { get; set; }

        [Display(Name = "Climate notes")]
        public string? ClimateNotes { get; set; }

        [Display(Name = "General notes")]
        public string? LocationGeneralNotes { get; set; }
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return Page();

        int newId;

        try
        {
            newId = await _db.Database
                .SqlQuery<int>($@"
                    CALL spAddLocation(
                        {Input.LocationName},
                        {Input.LocationTypeCode},
                        {Input.LocationNotes},
                        {Input.ClimateCode},
                        {Input.ClimateNotes},
                        {Input.LocationGeneralNotes}
                    );
                ")
                .SingleAsync(ct);
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var message))
            {
                ModelState.AddModelError(string.Empty, message);
                return Page();
            }

            throw;
        }

        return RedirectToPage(
            "../Details",
            new
            {
                locationId = newId,
                returnUrl = ReturnUrl
            });
    }
}
