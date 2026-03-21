using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Pages.Setup.Genera.Actions;

public class EditModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;
    private readonly IStoredProcedureExecutor _sp;

    public EditModel(OrchidDbContext db, IStoredProcedureExecutor sp)
    {
        _db = db;
        _sp = sp;
    }

    [BindProperty]
    public EditGenusDto Genus { get; set; } = new();

    public bool IsInactive { get; private set; }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var genus = await _db.Genera
            .AsNoTracking()
            .SingleOrDefaultAsync(g => g.GenusId == id);

        if (genus == null)
            return NotFound();

        Genus = new EditGenusDto
        {
            GenusId = genus.GenusId,
            Name = genus.Name,
            Notes = genus.Notes
        };

        IsInactive = !genus.IsActive;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
            return Page();

        try
        {
            await _sp.QuerySingleAsync<object>(
                "spUpdateGenus",
                new StoredProcedureParameter("pGenusId", Genus.GenusId),
                new StoredProcedureParameter("pGenusName", Genus.Name),
                new StoredProcedureParameter("pGenusNotes", Genus.Notes)
            );
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

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage("/Setup/Genera/Details", new { id = Genus.GenusId });
    }

    private async Task ReloadInactiveStateAsync(int id)
    {
        var genus = await _db.Genera
            .AsNoTracking()
            .SingleOrDefaultAsync(g => g.GenusId == id);

        IsInactive = genus != null && !genus.IsActive;
    }

    public sealed class EditGenusDto
    {
        public int GenusId { get; set; }

        [Required]
        [Display(Name = "Genus name")]
        public string Name { get; set; } = string.Empty;

        [Display(Name = "Genus notes")]
        public string? Notes { get; set; }
    }

    public sealed class UpdateGenusResult
    {
        public int GenusId { get; set; }
    }
}