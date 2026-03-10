using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.Data.Common;

namespace OrchidApp.Web.Pages.Setup.GrowthMedia.Actions;

public class AddModel : PageModel
{
    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty]
    public InputModel Input { get; set; } = new();

    public IActionResult OnGet()
    {
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        try
        {
            var result = await _db.GrowthMediumIdResults
                .FromSqlRaw(
                    "CALL spAddGrowthMedium({0}, {1})",
                    Input.Name,
                    Input.Description)
                .ToListAsync();

            var id = result.First().GrowthMediumId;

            return RedirectToPage("/Setup/GrowthMedia/Details",
                new { growthMediumId = id });
        }
        catch (DbException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Page();
        }
    }

    public class InputModel
    {
        [Required]
        [Display(Name = "Growth medium")]
        public string Name { get; set; } = string.Empty;

        [Display(Name = "Description")]
        public string? Description { get; set; }
    }
}