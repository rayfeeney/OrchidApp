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
    private readonly StoragePathService _storagePathService;
    private readonly PhotoPipeline _photoPipeline;
    private readonly ILogger<IndexModel> _logger;
    private readonly PhotoUrlService _photoUrlService;
    private readonly PhotoWriteBatch _photoWriteBatch;

    public IndexModel(
        OrchidDbContext context,
        ObservationTypeResolver resolver,
        PhotoPipeline photoPipeline,
        StoragePathService storagePathService,
        ILogger<IndexModel> logger,
        PhotoUrlService photoUrlService,
        PhotoWriteBatch photoWriteBatch)
    {
        _context = context;
        _resolver = resolver;
        _photoPipeline = photoPipeline;
        _storagePathService = storagePathService;
        _logger = logger;
        _photoUrlService = photoUrlService;
        _photoWriteBatch = photoWriteBatch;
    }

    public int PlantId { get; private set; }

    public List<PhotoItem> Photos { get; private set; } = new();

    public PhotoItem? FocusPhoto { get; private set; }

    [BindProperty(SupportsGet = true)]
    public int? FocusPhotoId { get; set; }

    public int? PreviousPhotoId { get; private set; }
    public int? NextPhotoId { get; private set; }
    public PhotoUrlService PhotoUrlService => _photoUrlService;
    public string PlantDisplayName { get; private set; } = string.Empty;
    public string PlantTag { get; private set; } = string.Empty;
    public string? LocationName { get; private set; }
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;
    public bool IsEnded { get; private set; }

    [BindProperty]
    [Display(Name = "Photos")]
    public List<IFormFile> UploadFiles { get; set; } = new();

    [BindProperty]
    [Display(Name = "Notes")]
    public string? UploadNotes { get; set; }

    public async Task<IActionResult> OnGetAsync(int plantId, CancellationToken ct)
    {
        PlantId = plantId;

        var plantEndDate = await _context.Plants
            .Where(p => p.PlantId == plantId)
            .Select(p => p.EndDate)
            .SingleAsync(ct);

        IsEnded = plantEndDate != null;
        
        var ok = await LoadAsync(plantId, FocusPhotoId, ct);
        if (!ok)
            return NotFound();

        return Page();
    }

    private async Task<bool> IsPlantEndedAsync(int plantId, CancellationToken ct)
    {
        return await _context.Plants
            .Where(p => p.PlantId == plantId)
            .Select(p => p.EndDate != null)
            .SingleAsync(ct);
    }

    public async Task<IActionResult> OnPostSetHeroAsync(int plantId, int photoId, CancellationToken ct)
    {
        if (await IsPlantEndedAsync(plantId, ct))
            return BadRequest();
    
        await _context.Database.ExecuteSqlRawAsync(
            "CALL spSetHeroPhoto({0}, {1})",
            new object[] { plantId, photoId },
            ct);

        return RedirectToPage(new { plantId, focusPhotoId = photoId, returnUrl = ReturnUrl });
    }

    public async Task<IActionResult> OnPostDeleteAsync(int plantId, int photoId, bool confirmDelete, CancellationToken ct)
    {
        // PlantWriteFilter holds the parent row lock and enforces ended-plant policy.
        if (!confirmDelete)
            return RedirectToPage(new { plantId, focusPhotoId = photoId, returnUrl = ReturnUrl });
        var photo = await _context.PlantPhotos.SingleOrDefaultAsync(
            p => p.PlantId == plantId && p.PlantPhotoId == photoId && p.IsActive, ct);
        if (photo == null) return NotFound();

        try
        {
            var names = new[] { photo.FileName, photo.ThumbnailFileName }
                .Where(name => !string.IsNullOrWhiteSpace(name)).Select(name => name!).Distinct().ToArray();
            // Do not remove a file shared by other metadata, including inactive rows.
            if (await _context.PlantPhotos.AnyAsync(p => p.PlantId == plantId && p.PlantPhotoId != photoId &&
                (names.Contains(p.FileName) || names.Contains(p.ThumbnailFileName!)), ct))
                throw new InvalidOperationException("Photo files are shared by another record.");
            _photoWriteBatch.TrackDeletion(plantId, names);
        }
        catch (Exception ex) when (ex is InvalidOperationException or IOException or UnauthorizedAccessException)
        {
            _logger.LogWarning(ex, "Photo deletion preparation failed for plant {PlantId}, photo {PhotoId}", plantId, photoId);
            ModelState.AddModelError(string.Empty, "The photo could not be deleted. No photo files were removed. If the problem persists, review the application log.");
            PlantId = plantId;
            FocusPhotoId = photoId;
            await LoadAsync(plantId, photoId, ct);
            return Page();
        }
        _context.PlantPhotos.Remove(photo);
        await _context.SaveChangesAsync(ct);
        if (photo.IsHero)
        {
            var replacement = await _context.PlantPhotos.Where(p => p.PlantId == plantId && p.IsActive)
                .OrderByDescending(p => p.CreatedDateTime).ThenByDescending(p => p.PlantPhotoId).FirstOrDefaultAsync(ct);
            if (replacement != null)
            {
                replacement.IsHero = true;
                await _context.SaveChangesAsync(ct);
            }
        }
        return RedirectToPage(new { plantId, returnUrl = ReturnUrl });
    }

    public async Task<IActionResult> OnPostUploadAsync(int plantId, string? returnUrl, CancellationToken ct)
    {
        if (await IsPlantEndedAsync(plantId, ct))
            return BadRequest();

        var acquired = await _context.Plants.Where(p => p.PlantId == plantId)
            .Select(p => p.AcquisitionDate).SingleAsync(ct);
        if (acquired.HasValue && DateTime.Today < acquired.Value.Date)
            return BadRequest("Photos cannot be added before the plant was acquired.");
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
            await AddPhotoObservationAsync(
                PlantId,
                UploadFiles,
                combinedNotes,
                ct);
        }
        catch (InvalidOperationException)
        {
            ModelState.AddModelError(string.Empty,
                "The photo could not be processed. Please try another image.");

            var ok = await LoadAsync(plantId, FocusPhotoId, ct);
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
        var plant = await _context.PlantCurrentLocations
            .Where(p => p.PlantId == plantId)
            .Select(p => new
            {
                DisplayName = p.DisplayName!,
                PlantTag = p.PlantTag!,
                p.LocationName,
                p.TaxonId          // added
            })
            .FirstOrDefaultAsync(ct);

        if (plant == null)
            return false;

        PlantDisplayName = plant.DisplayName;
        PlantTag = plant.PlantTag;
        LocationName = plant.LocationName;

        // taxonomy state (NEW)
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
                FileName = p.FileName,
                ThumbnailFileName = p.ThumbnailFileName!,
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
        var now = DateTime.Now;

        var observation = new PlantEvent
        {
            PlantId = plantId,
            EventDateTime = now,
            ObservationTypeId = observationTypeId,
            EventDetails = notes,
            IsActive = true
        };

        _context.PlantEvent.Add(observation);
        await _context.SaveChangesAsync(ct); // must save first to get PlantEventId

        var uploadsRoot = _storagePathService.GetUploadRoot();

        var heroExists = await _context.PlantPhotos
            .AnyAsync(p => p.PlantId == plantId && p.IsHero && p.IsActive, ct);

        foreach (var file in files)
        {
            if (file == null || file.Length <= 0)
                continue;

            PhotoSaveResult result;

            try
            {
                result = await _photoPipeline.ProcessAndSaveAsync(
                    file.OpenReadStream(),
                    new PhotoStorageTarget
                    {
                        EntityType = "plants",
                        EntityId = plantId.ToString()
                    },
                    uploadsRoot,
                    ct);
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex,
                    "Photo ingestion failed for plant {PlantId}", plantId);

                throw new InvalidOperationException(
                    "The photo could not be processed. Please try another image.");
            }

            var photo = new PlantPhoto
            {
                PlantEventId = observation.PlantEventId,
                PlantId = plantId,
                FileName = result.FileName,
                ThumbnailFileName = result.ThumbnailFileName,
                MimeType = result.MimeType,
                IsHero = !heroExists,
                IsActive = true,
                CreatedDateTime = now
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
        public string FileName { get; set; } = "";
        public string ThumbnailFileName { get; set; } = "";
        public bool IsHero { get; set; }
        public DateTime CreatedDateTime { get; set; }
    }
}
