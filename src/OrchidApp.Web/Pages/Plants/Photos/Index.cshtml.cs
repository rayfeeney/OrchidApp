using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;

namespace OrchidApp.Web.Pages.Plants.Photos;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _context;

    public IndexModel(OrchidDbContext context)
    {
        _context = context;
    }

    public int PlantId { get; private set; }

    public List<PhotoItem> Photos { get; private set; } = new();

    public PhotoItem? FocusPhoto { get; private set; }

    [BindProperty(SupportsGet = true)]
    public int? FocusPhotoId { get; set; }

    public int? PreviousPhotoId { get; private set; }
    public int? NextPhotoId { get; private set; }

    public async Task<IActionResult> OnGetAsync(int plantId)
    {
        PlantId = plantId;

        Photos = await _context.PlantPhotos
            .Where(p => p.PlantId == plantId && p.IsActive)
            .OrderByDescending(p => p.CreatedDateTime)
            .Select(p => new PhotoItem
            {
                PlantPhotoId = p.PlantPhotoId,
                FilePath = p.FilePath,
                IsHero = p.IsHero,
                CreatedDateTime = p.CreatedDateTime
            })
            .ToListAsync();

        if (Photos.Count == 0)
        {
            return RedirectToPage("/Plants/Details", new { id = plantId });
        }

        FocusPhoto = FocusPhotoId.HasValue
            ? Photos.FirstOrDefault(p => p.PlantPhotoId == FocusPhotoId.Value)
            : Photos.FirstOrDefault(p => p.IsHero) ?? Photos.First();

        // Work out previous/next based on the current ordering of Photos
        var focusIndex = Photos.FindIndex(p => p.PlantPhotoId == FocusPhoto?.PlantPhotoId);

        if (focusIndex > 0)
        {
            PreviousPhotoId = Photos[focusIndex - 1].PlantPhotoId;
        }

        if (focusIndex >= 0 && focusIndex < Photos.Count - 1)
        {
            NextPhotoId = Photos[focusIndex + 1].PlantPhotoId;
        }

        return Page();
    }

    public async Task<IActionResult> OnPostSetHeroAsync(int plantId, int photoId)
    {
        await _context.Database.ExecuteSqlRawAsync(
            "CALL spSetHeroPhoto({0}, {1})",
            plantId,
            photoId);

        return RedirectToPage(
            new { plantId = plantId, focusPhotoId = photoId });
    }

    public sealed class PhotoItem
    {
        public int PlantPhotoId { get; set; }
        public string FilePath { get; set; } = "";
        public bool IsHero { get; set; }
        public DateTime CreatedDateTime { get; set; }
    }
}