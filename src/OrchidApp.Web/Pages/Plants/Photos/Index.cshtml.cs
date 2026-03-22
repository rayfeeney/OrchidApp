using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Pages.Plants.Photos;

public class IndexModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _context;
    private readonly ObservationTypeResolver _resolver;
    private readonly PhotoPipeline _photoPipeline;

    public IndexModel(
        OrchidDbContext context,
        ObservationTypeResolver resolver,
        PhotoPipeline photoPipeline)
    {
        _context = context;
        _resolver = resolver;
        _photoPipeline = photoPipeline;
    }

    public int PlantId { get; private set; }

    public List<PhotoItem> Photos { get; private set; } = new();

    public PhotoItem? FocusPhoto { get; private set; }

    [BindProperty(SupportsGet = true)]
    public int? FocusPhotoId { get; set; }

    public int? PreviousPhotoId { get; private set; }
    public int? NextPhotoId { get; private set; }

    public string PlantDisplayName { get; private set; } = string.Empty;
    public string PlantTag { get; private set; } = string.Empty;
    public string? LocationName { get; private set; }
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    [BindProperty]
    [Display(Name = "Photos")]
    public List<IFormFile> UploadFiles { get; set; } = new();

    [BindProperty]
    [Display(Name = "Notes")]
    public string? UploadNotes { get; set; }

    public async Task<IActionResult> OnGetAsync(int plantId, CancellationToken ct)
    {
        PlantId = plantId;

        var ok = await LoadAsync(plantId, FocusPhotoId, ct);
        if (!ok)
            return NotFound();

        return Page();
    }

    public async Task<IActionResult> OnPostSetHeroAsync(int plantId, int photoId, CancellationToken ct)
    {
        await _context.Database.ExecuteSqlRawAsync(
            "CALL spSetHeroPhoto({0}, {1})",
            new object[] { plantId, photoId },
            ct);

        return RedirectToPage(new { plantId, focusPhotoId = photoId });
    }

    public async Task<IActionResult> OnPostUploadAsync(int plantId, string? returnUrl, CancellationToken ct)
    {
        PlantId = plantId;
        ReturnUrl = returnUrl;

        if (UploadFiles == null || UploadFiles.Count == 0)
        {
            ModelState.AddModelError(nameof(UploadFiles), "Select at least one photo.");

            var ok = await LoadAsync(plantId, focusPhotoId: FocusPhotoId, ct);
            if (!ok)
                return NotFound();

            return Page();
        }

        var prefix = "Photo added";
        var combinedNotes = string.IsNullOrWhiteSpace(UploadNotes)
            ? prefix
            : $"{prefix} {UploadNotes.Trim()}";

        try
        {
            await AddPhotoObservationAsync(plantId, UploadFiles, combinedNotes, ct);
        }
        catch (InvalidOperationException ex)
        {
            // PhotoPipeline validation errors (too large, bad format, etc)
            ModelState.AddModelError(string.Empty, ex.Message);

            var ok = await LoadAsync(plantId, focusPhotoId: FocusPhotoId, ct);
            if (!ok)
                return NotFound();

            return Page();
        }

        if (!string.IsNullOrWhiteSpace(returnUrl))
            return LocalRedirect(returnUrl);

        return RedirectToPage(new { plantId });
    }

    private async Task<bool> LoadAsync(int plantId, int? focusPhotoId, CancellationToken ct)
    {
        var plant = await _context.PlantActiveCurrentLocations
            .Where(p => p.PlantId == plantId)
            .Select(p => new
            {
                DisplayName = p.DisplayName!,
                PlantTag = p.PlantTag!,
                p.LocationName,
                p.TaxonId          // ✅ added
            })
            .FirstOrDefaultAsync(ct);

        if (plant == null)
            return false;

        PlantDisplayName = plant.DisplayName;
        PlantTag = plant.PlantTag;
        LocationName = plant.LocationName;

        // ✅ taxonomy state (NEW)
        var taxon = await _context.TaxonIdentities
            .Where(t => t.TaxonId == plant.TaxonId)
            .Select(t => new
            {
                t.GenusIsActive,
                t.TaxonIsActive
            })
            .SingleAsync(ct);

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

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
            .ToListAsync(ct);

        if (Photos.Any())
        {
            FocusPhoto = focusPhotoId.HasValue
                ? Photos.FirstOrDefault(p => p.PlantPhotoId == focusPhotoId.Value)
                : Photos.FirstOrDefault(p => p.IsHero) ?? Photos.First();
        }
        else
        {
            FocusPhoto = null;
        }

        var focusIndex = Photos.FindIndex(p => p.PlantPhotoId == FocusPhoto?.PlantPhotoId);

        PreviousPhotoId = focusIndex > 0 ? Photos[focusIndex - 1].PlantPhotoId : null;
        NextPhotoId = (focusIndex >= 0 && focusIndex < Photos.Count - 1)
            ? Photos[focusIndex + 1].PlantPhotoId
            : null;

        return true;
    }

    private async Task AddPhotoObservationAsync(
        int plantId,
        List<IFormFile> files,
        string? notes,
        CancellationToken ct)
    {
        // Always a photo observation from this page
        var observationTypeId = await _resolver.GetIdAsync("OBS_PHOTO");

        var observation = new PlantEvent
        {
            PlantId = plantId,
            EventDateTime = DateTime.Now,
            ObservationTypeId = observationTypeId,
            EventDetails = notes,
            IsActive = true
        };

        _context.PlantEvent.Add(observation);
        await _context.SaveChangesAsync(ct); // must save first to get PlantEventId

        var uploadsRoot = "/opt/orchidapp/uploads";

        var heroExists = await _context.PlantPhotos
            .AnyAsync(p => p.PlantId == plantId && p.IsHero && p.IsActive, ct);

        foreach (var file in files)
        {
            if (file == null || file.Length <= 0)
                continue;

            var result = await _photoPipeline.ProcessAndSaveAsync(
                file.OpenReadStream(),
                plantId,
                uploadsRoot,
                ct);

            var photo = new PlantPhoto
            {
                PlantEventId = observation.PlantEventId,
                PlantId = plantId,
                FileName = file.FileName,
                FilePath = result.RelativePath,
                MimeType = result.MimeType,
                IsHero = !heroExists,
                IsActive = true,
                CreatedDateTime = DateTime.Now
            };

            _context.PlantPhotos.Add(photo);

            if (!heroExists)
                heroExists = true;
        }

        await _context.SaveChangesAsync(ct);
    }

    public sealed class PhotoItem
    {
        public int PlantPhotoId { get; set; }
        public string FilePath { get; set; } = "";
        public bool IsHero { get; set; }
        public DateTime CreatedDateTime { get; set; }
    }
}