using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

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

        var entity = new GrowthMedium
        {
            Name = Input.Name.Trim(),
            Description = string.IsNullOrWhiteSpace(Input.Description)
                ? null
                : Input.Description.Trim(),
            IsActive = true
        };

        _db.GrowthMedia.Add(entity);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(
                nameof(Input.Name),
                "A growth medium with this name already exists."
            );
            return Page();
        }

        return RedirectToPage(
            "/Setup/GrowthMedia/Details",
            new { growthMediumId = entity.GrowthMediumId }
        );
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