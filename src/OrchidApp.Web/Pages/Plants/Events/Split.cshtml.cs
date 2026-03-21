using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using OrchidApp.Web.Infrastructure;
using System.Text.Json;

namespace OrchidApp.Web.Pages.Plants.Events;

public class SplitModel : PageModel
{
    private readonly OrchidDbContext _db;

    public SplitModel(OrchidDbContext db)
    {
        _db = db;
    }

    // =============================
    // ROUTING
    // =============================

    [FromRoute]
    public int PlantId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    // =============================
    // PAGE STATE
    // =============================

    public PlantCurrentLocation? Plant { get; private set; }

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }

    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    // =============================
    // FORM STATE
    // =============================

    [BindProperty]
    public int ChildCount { get; set; } = 2;

    [BindProperty]
    public List<ChildInput> Children { get; set; } = new();

    [BindProperty]
    public DateTime SplitDateTime { get; set; }
        = DateTime.Now.AddSeconds(-DateTime.Now.Second)
                      .AddMilliseconds(-DateTime.Now.Millisecond);

    [BindProperty]
    public string? SplitReasonNotes { get; set; }

    public class ChildInput
    {
        [Display(Name = "Plant name")]
        public string? PlantName { get; set; }
    }

    // =============================
    // LOAD PAGE STATE
    // =============================

    private async Task LoadPageStateAsync()
    {
        Plant = await _db.PlantCurrentLocations
            .FirstOrDefaultAsync(p => p.PlantId == PlantId);

        if (Plant == null)
            throw new InvalidOperationException("Plant not found.");

        var taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == Plant.TaxonId)
            .Select(t => new
            {
                t.GenusIsActive,
                t.TaxonIsActive
            })
            .SingleAsync();

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;
    }

    private void EnsureChildListLength()
    {
        if (Children == null)
            Children = new();

        while (Children.Count < ChildCount)
            Children.Add(new ChildInput());
    }

    // =============================
    // GET
    // =============================

    public async Task<IActionResult> OnGetAsync()
    {
        await LoadPageStateAsync();

        if (Plant!.PlantEndDate != null)
            return BadRequest("Cannot split an ended plant.");

        if (ChildCount < 2)
            ChildCount = 2;

        Children = Enumerable.Range(0, ChildCount)
            .Select(_ => new ChildInput())
            .ToList();

        return Page();
    }

    // =============================
    // ADD CHILD
    // =============================

    public async Task<IActionResult> OnPostAddChildAsync()
    {
        await LoadPageStateAsync();

        if (ChildCount < 2)
            ChildCount = 2;

        ChildCount++;

        EnsureChildListLength();

        return Page();
    }

    // =============================
    // SPLIT
    // =============================

    public async Task<IActionResult> OnPostSplitAsync()
    {
        var parentPlant = await _db.Plants
            .FirstOrDefaultAsync(p => p.PlantId == PlantId);

        if (parentPlant == null)
            return NotFound();

        await LoadPageStateAsync();

        if (IsInactive)
        {
            ModelState.AddModelError(string.Empty,
                "This plant cannot be split because its taxonomy is inactive.");
            EnsureChildListLength();
            return Page();
        }

        if (parentPlant.EndDate != null)
        {
            ModelState.AddModelError(string.Empty,
                "This plant can no longer be split.");
            EnsureChildListLength();
            return Page();
        }

        if (SplitDateTime > DateTime.Now)
        {
            ModelState.AddModelError(nameof(SplitDateTime),
                "Split date and time cannot be in the future.");
            EnsureChildListLength();
            return Page();
        }

        if (SplitDateTime < parentPlant.AcquisitionDate)
        {
            ModelState.AddModelError(nameof(SplitDateTime),
                "Split date and time cannot be before this plant’s lifecycle began.");
            EnsureChildListLength();
            return Page();
        }

        if (ChildCount < 2)
            ChildCount = 2;

        var filledChildren = Children.ToList();

        var json = JsonSerializer.Serialize(
            filledChildren.Select(c => new
            {
                plantName = string.IsNullOrWhiteSpace(c.PlantName)
                    ? null
                    : c.PlantName.Trim()
            })
        );

        SplitReasonNotes = string.IsNullOrWhiteSpace(SplitReasonNotes)
            ? null
            : SplitReasonNotes.Trim();

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spSplitPlant({0},{1},{2},{3},{4});",
                PlantId,
                SplitDateTime,
                json,
                DBNull.Value,
                (object?)SplitReasonNotes ?? DBNull.Value
            );

            return RedirectToPage("/Plants/Details", new { plantId = PlantId });
        }
        catch (Exception ex) when (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
        {
            ModelState.AddModelError(string.Empty, msg);
            EnsureChildListLength();
            return Page();
        }
    }
}