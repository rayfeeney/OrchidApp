using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System.ComponentModel.DataAnnotations;
using OrchidApp.Web.Infrastructure;

namespace OrchidApp.Web.Pages.Plants.Events;

public class SplitModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public SplitModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;
    public PlantCurrentLocation? Plant { get; private set; }

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
        [Required]
        [Display(Name = "Plant tag")]
        public string? PlantTag { get; set; }
        [Display(Name = "Plant name")]
        public string? PlantName { get; set; }
    }

    private void EnsureChildListLength()
    {
        if (Children == null)
            Children = new List<ChildInput>();

        while (Children.Count < ChildCount)
        {
            Children.Add(new ChildInput());
        }
    }

    public IActionResult OnGet()
    {
        Plant = _db.PlantCurrentLocations
                .FirstOrDefault(p => p.PlantId == PlantId);

        if (Plant == null)
            return NotFound();

        if (Plant.PlantEndDate != null)
            return BadRequest("Cannot split an ended plant.");

        var taxon = _db.TaxonIdentities
            .Where(t => t.TaxonId == Plant.TaxonId)
            .Select(t => new
            {
                t.GenusIsActive,
                t.TaxonIsActive
            })
            .Single();

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

        if (IsInactive)
            return BadRequest("Cannot split plant because taxonomy is inactive.");

        if (ChildCount < 2)
            ChildCount = 2;

        Children = Enumerable.Range(0, ChildCount)
                            .Select(_ => new ChildInput())
                            .ToList();

        return Page();
    }

    public IActionResult OnPostAddChild()
    {
        if (ChildCount < 2)
            ChildCount = 2;

        ChildCount++;

        if (Children == null)
            Children = new List<ChildInput>();

        while (Children.Count < ChildCount)
        {
            Children.Add(new ChildInput());
        }

        return Page();
    }

    public async Task<IActionResult> OnPostSplit()
    {
        var parentPlant = await _db.Plants
            .FirstOrDefaultAsync(p => p.PlantId == PlantId);

        if (parentPlant == null)
            return NotFound();

        var taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == parentPlant.TaxonId)
            .Select(t => new
            {
                t.GenusIsActive,
                t.TaxonIsActive
            })
            .SingleAsync();

        if (!taxon.GenusIsActive || !taxon.TaxonIsActive)
        {
            ModelState.AddModelError(string.Empty,
                "Cannot split plant because taxonomy is inactive.");
            EnsureChildListLength();
            return Page();
        }

        if (parentPlant == null)
            return NotFound();

        if (parentPlant.EndDate != null)
        {
            ModelState.AddModelError(string.Empty,
                "This plant can no longer be split.");
            EnsureChildListLength();
            return Page();
        }

        SplitReasonNotes = string.IsNullOrWhiteSpace(SplitReasonNotes)
            ? null
            : SplitReasonNotes.Trim();

        if (ChildCount < 2)
            ChildCount = 2;

        var filledChildren = Children
            .Where(c => !string.IsNullOrWhiteSpace(c.PlantTag))
            .ToList();

        if (filledChildren.Count < 2)
        {
            ModelState.AddModelError(string.Empty,
                "You must provide at least two child plant tags.");
            EnsureChildListLength();
            return Page();
        }

        var tags = filledChildren
            .Select(c => c.PlantTag!.Trim())
            .ToList();

        var duplicateTags = tags
            .GroupBy(t => t)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key)
            .ToList();

        if (duplicateTags.Any())
        {
            ModelState.AddModelError(string.Empty,
                "Duplicate plant tags are not allowed.");
            EnsureChildListLength();
            return Page();
        }

        var existingTags = await _db.Plants
            .Where(p => p.PlantTag != null && tags.Contains(p.PlantTag))
            .Select(p => p.PlantTag!)
            .ToListAsync();

        if (existingTags.Any())
        {
            ModelState.AddModelError(string.Empty,
                $"The following plant tags already exist: {string.Join(", ", existingTags)}");
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

        var csv = string.Join(",", tags);

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spSplitPlant({0},{1},{2},{3},{4},{5});",
                PlantId,
                SplitDateTime,
                csv,
                (object)null!,
                (object?)SplitReasonNotes ?? (object)null!,
                (object)null!
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
