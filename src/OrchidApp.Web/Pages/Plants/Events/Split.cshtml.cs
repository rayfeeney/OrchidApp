using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Plants.Events;

public class SplitModel : PageModel
{
    private readonly OrchidDbContext _db;

    public SplitModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public PlantCurrentLocation? Plant { get; private set; }

    [BindProperty]
    public int ChildCount { get; set; } = 2;

    [BindProperty]
    public List<ChildInput> Children { get; set; } = new();

    public class ChildInput
    {
        public string? PlantTag { get; set; }
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

    public IActionResult OnPostSplit()
    {
        // Ensure minimum rows
        if (ChildCount < 2)
            ChildCount = 2;

        // Remove completely empty rows
        var filledChildren = Children
            .Where(c => !string.IsNullOrWhiteSpace(c.PlantTag))
            .ToList();

        // Rule 1: At least two children
        if (filledChildren.Count < 2)
        {
            ModelState.AddModelError(string.Empty,
                "You must provide at least two child plant tags.");
            EnsureChildListLength();
            return Page();
        }

        // Rule 2: PlantTag mandatory for filled rows
        foreach (var child in filledChildren)
        {
            if (string.IsNullOrWhiteSpace(child.PlantTag))
            {
                ModelState.AddModelError(string.Empty,
                    "Plant tag is required for each child.");
                EnsureChildListLength();
                return Page();
            }
        }

        // Rule 3: No duplicate tags within form
        var duplicateTags = filledChildren
            .GroupBy(c => c.PlantTag!.Trim())
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

        // Rule 4: No duplicate plant tags in database
        var existingTags = _db.Plants
            .Where(p => filledChildren.Select(c => c.PlantTag!.Trim())
                                    .Contains(p.PlantTag))
            .Select(p => p.PlantTag)
            .ToList();

        if (existingTags.Any())
        {
            ModelState.AddModelError(string.Empty,
                $"The following plant tags already exist: {string.Join(", ", existingTags)}");

            EnsureChildListLength();
            return Page();
        }

        // If validation passes for now
        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }

}
