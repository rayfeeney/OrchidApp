using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using OrchidApp.Web.Data;
using OrchidApp.Web.Infrastructure;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;
using System;
using System.ComponentModel.DataAnnotations;
using System.IO;
using System.Linq;


namespace OrchidApp.Web.Pages.Plants.Events;

public class AddModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;
    private readonly ObservationTypeResolver _resolver;
    private readonly PhotoPipeline _photoPipeline;
    private readonly StoragePathService _storagePathService;
    private readonly IStoredProcedureExecutor _sp;
    private readonly ILogger<AddModel> _logger;

    public AddModel(
        OrchidDbContext db,
        ObservationTypeResolver resolver,
        PhotoPipeline photoPipeline,
        StoragePathService storagePathService,
        IStoredProcedureExecutor sp,
        ILogger<AddModel> logger)
    {
        _db = db;
        _resolver = resolver;
        _photoPipeline = photoPipeline;
         _storagePathService = storagePathService;
        _sp = sp;
        _logger = logger;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    [FromRoute]
    public string EventType { get; set; } = "Observation";

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime EventDate { get; set; } = DateTime.Today;

    [BindProperty]
    public string? EventDetails { get; set; }

    [BindProperty]
    public List<IFormFile>? UploadedFiles { get; set; }

    [BindProperty]
    public bool ShowPhotoSection { get; set; }

    [BindProperty]
    public int? LocationId { get; set; }
    [BindProperty]
    public string? QuickObservationTypeCode { get; set; }
    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime StartDate { get; set; } = DateTime.Today;

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime? EndDate { get; set; }

    [BindProperty] public int? SpikeCount { get; set; }
    [BindProperty] public int? FlowerCount { get; set; }
    [BindProperty] public string? PlantLocationNotes { get; set; }

    [BindProperty] public int? OldGrowthMediumId { get; set; }
    [BindProperty] public int? NewGrowthMediumId { get; set; }
    [BindProperty] public string? OldMediumNotes { get; set; }
    [BindProperty] public string? NewMediumNotes { get; set; }
    [BindProperty] public string? PotSize { get; set; }
    [BindProperty] public string? RepotReasonNotes { get; set; }
    [BindProperty] public string? RepottingNotes { get; set; }

    public List<Location> Locations { get; private set; } = new();
    public List<GrowthMedium> GrowthMedia { get; private set; } = new();

    private bool LoadPlantContext()
    {
        var plant = _db.PlantActiveSummaries
            .FirstOrDefault(p => p.PlantId == PlantId);

        if (plant == null)
            return false;

        PlantDisplayName = plant.DisplayName;
        PlantTag = plant.PlantTag;

        var taxon = _db.TaxonIdentities
            .Where(t => t.TaxonId == plant.TaxonId)
            .Select(t => new { t.GenusIsActive, t.TaxonIsActive })
            .Single();

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

        return true;
    }

    private void LoadLookups()
    {
        Locations = _db.Location
            .Where(l => l.IsActive)
            .OrderBy(l => l.LocationName)
            .ToList();

        GrowthMedia = _db.GrowthMedia
            .Where(g => g.IsActive)
            .OrderBy(g => g.Name)
            .ToList();
    }

    private IActionResult ReloadPageWithLookups()
    {
        if (!LoadPlantContext())
            return NotFound();

        var currentMedium = _db.PlantCurrentGrowthMedium
            .FirstOrDefault(x => x.PlantId == PlantId);

        OldGrowthMediumId = currentMedium?.GrowthMediumId;        

        LoadLookups();
        return Page();
    }

    public IActionResult OnGet()
    {
        if (EventType is not ("Observation" or "LocationChange" or "Flowering" or "Repotting"))
            return NotFound();

        return ReloadPageWithLookups();
    }

    public async Task<IActionResult> OnPostAsync(string? quickAction)
    {
        var now = DateTime.Now;

        if (EventType is not ("Observation" or "LocationChange" or "Flowering" or "Repotting"))
            return NotFound();

        if (!LoadPlantContext())
            return NotFound();

        if (IsInactive)
        {
            ModelState.AddModelError(string.Empty,
                "Events cannot be added because this plant’s taxonomy is inactive.");
            LoadLookups();
            return Page();
        }

        if (!string.IsNullOrWhiteSpace(quickAction) && EventType == "Observation")
        {
            switch (quickAction)
            {
                case "photo":
                    EventDetails = "Photo added";
                    ShowPhotoSection = true;
                    QuickObservationTypeCode = "OBS_PHOTO";
                    break;

                case "feedGrowth":
                    EventDetails = "Fed with growth food";
                    QuickObservationTypeCode = "OBS_FEED_GROWTH";
                    break;

                case "feedBloom":
                    EventDetails = "Fed with bloom food";
                    QuickObservationTypeCode = "OBS_FEED_BLOOM";
                    break;
            }

            ModelState.Remove(nameof(EventDetails));
            ModelState.Remove(nameof(ShowPhotoSection));
            ModelState.Remove(nameof(QuickObservationTypeCode));

            LoadLookups();
            return Page();
        }

        if (!ModelState.IsValid)
        {
            LoadLookups();
            return Page();
        }

        switch (EventType)
        {
            case "Observation":
            {
                // =========================
                // Basic input validation
                // =========================

                var uploadedFiles = UploadedFiles?
                    .Where(f => f != null && f.Length > 0)
                    .ToList() ?? new List<IFormFile>();

                var hasPhotos = uploadedFiles.Any();
                var wantsPhotoObservation = ShowPhotoSection;

                if (wantsPhotoObservation && !hasPhotos)
                {
                    ModelState.AddModelError(nameof(UploadedFiles),
                        "Please choose at least one photo.");
                }

                if (string.IsNullOrWhiteSpace(QuickObservationTypeCode)
                    && !hasPhotos
                    && string.IsNullOrWhiteSpace(EventDetails))
                {
                    ModelState.AddModelError(nameof(EventDetails),
                        "Please enter some notes or choose an observation type.");
                }

                // =========================
                // Date validation (Observation rules)
                // =========================

                var plant = await _db.Plants
                    .AsNoTracking()
                    .Where(p => p.PlantId == PlantId)
                    .Select(p => new { p.AcquisitionDate, p.EndDate })
                    .SingleAsync();

                var eventDate = EventDate.Date;

                // Rule 1 — cannot be in the future
                if (eventDate > DateTime.Today)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Observation date cannot be in the future.");
                }

                // Rule 2 — cannot be before acquisition
                if (plant.AcquisitionDate.HasValue &&
                    eventDate < plant.AcquisitionDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Observation date cannot be before the plant was acquired.");
                }

                // Rule 3 — cannot be after end
                if (plant.EndDate.HasValue &&
                    eventDate > plant.EndDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Observation date cannot be after the plant has ended.");
                }

                // =========================
                // Stop if invalid
                // =========================

                if (!ModelState.IsValid)
                {
                    LoadLookups();
                    return Page();
                }

                // =========================
                // Continue with save
                // =========================

                string typeCode;

                if (!string.IsNullOrWhiteSpace(QuickObservationTypeCode))
                {
                    typeCode = QuickObservationTypeCode;
                }
                else
                {
                    typeCode = hasPhotos ? "OBS_PHOTO" : "OBS_NOTE";
                }

                var observationTypeId = await _resolver.GetIdAsync(typeCode);

                var uploadsRoot = _storagePathService.GetUploadRoot();
                var savedRelativePaths = new List<string>();

                await using var tx = await _db.Database.BeginTransactionAsync();

                try
                {
                    var observation = new PlantEvent
                    {
                        PlantId = PlantId,
                        EventDateTime = new DateTime(
                                        EventDate.Year,
                                        EventDate.Month,
                                        EventDate.Day,
                                        now.Hour,
                                        now.Minute,
                                        now.Second),
                        ObservationTypeId = observationTypeId,
                        EventDetails = EventDetails,
                        IsActive = true
                    };

                    _db.PlantEvent.Add(observation);
                    await _db.SaveChangesAsync();

                    if (hasPhotos)
                    {
                        var heroExists = await _db.PlantPhotos
                            .AnyAsync(p => p.PlantId == PlantId && p.IsHero && p.IsActive);

                        foreach (var file in uploadedFiles)
                        {
                            PhotoSaveResult result;

                            try
                            {
                                // This is the old way that PhotoPipeline worked and worked well on the Pi
                                await using var stream = file.OpenReadStream();

                                result = await _photoPipeline.ProcessAndSaveAsync(
                                    stream,
                                    new PhotoStorageTarget
                                    {
                                        EntityType = "plants",
                                        EntityId = PlantId.ToString()
                                    },
                                    uploadsRoot,
                                    HttpContext.RequestAborted); 
                            }
                            catch (InvalidOperationException ex)
                            {
                                _logger.LogWarning(ex,
                                    "Photo ingestion failed for plant {PlantId}", PlantId);

                                throw new InvalidOperationException(
                                    "The photo could not be processed. Please try another image.", ex);
                            }

                            savedRelativePaths.Add(result.FileName); // temporary, we’ll clean this later

                            var photo = new PlantPhoto
                            {
                                PlantEventId = observation.PlantEventId,
                                PlantId = PlantId,
                                FileName = result.FileName,
                                ThumbnailFileName = result.ThumbnailFileName,
                                MimeType = result.MimeType,
                                IsHero = !heroExists,
                                IsActive = true,
                                CreatedDateTime = now
                            };

                            _db.PlantPhotos.Add(photo);

                            if (!heroExists)
                                heroExists = true;
                        }

                        await _db.SaveChangesAsync();
                    }

                    await tx.CommitAsync();
                }
                catch (Exception ex)
                {
                    await tx.RollbackAsync();

                    foreach (var relativePath in savedRelativePaths)
                    {
                        try
                        {
                            var fullPath = Path.Combine(
                                uploadsRoot,
                                relativePath.Replace('/', Path.DirectorySeparatorChar));

                            if (System.IO.File.Exists(fullPath))
                                System.IO.File.Delete(fullPath);
                        }
                        catch (Exception cleanupEx)
                        {
                            _logger.LogWarning(cleanupEx,
                                "Failed to clean up photo file {RelativePath} for plant {PlantId}",
                                relativePath,
                                PlantId);
                        }
                    }

                    var message = ex is InvalidOperationException
                        ? ex.Message
                        : "The observation could not be saved.";

                    ModelState.AddModelError(string.Empty, message);
                    LoadLookups();
                    return Page();
                }

                break;
            }

            case "LocationChange":
            {
                // =========================
                // Basic validation
                // =========================

                if (!LocationId.HasValue)
                {
                    ModelState.AddModelError(nameof(LocationId),
                        "Please select a location.");

                    LoadLookups();
                    return Page();
                }

                // =========================
                // Load plant lifecycle
                // =========================

                var plant = await _db.Plants
                    .AsNoTracking()
                    .Where(p => p.PlantId == PlantId)
                    .Select(p => new { p.AcquisitionDate, p.EndDate })
                    .SingleAsync();

                var eventDate = EventDate.Date;

                // =========================
                // Date validation
                // =========================

                // Rule 1 — not in future
                if (eventDate > DateTime.Today)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Move date cannot be in the future.");
                }

                // Rule 2 — not before acquisition
                if (plant.AcquisitionDate.HasValue &&
                    eventDate < plant.AcquisitionDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Move date cannot be before the plant was acquired.");
                }

                // Rule 3 — not after plant end
                if (plant.EndDate.HasValue &&
                    eventDate > plant.EndDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Move date cannot be after the plant has ended.");
                }

                // =========================
                // Stop if invalid
                // =========================

                if (!ModelState.IsValid)
                {
                    LoadLookups();
                    return Page();
                }

                // =========================
                // Call stored procedure
                // =========================

                try
                {
                    await _sp.QueryListAsync<object>(
                        "spMovePlantToLocation",
                        new StoredProcedureParameter("pPlantId", PlantId),
                        new StoredProcedureParameter("pLocationId", LocationId.Value),
                        new StoredProcedureParameter("pStartDate", eventDate),
                        new StoredProcedureParameter("pMoveReasonNotes", EventDetails),
                        new StoredProcedureParameter("pPlantLocationNotes", PlantLocationNotes)
                    );
                }
                catch (Exception ex) when (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
                {
                    ModelState.AddModelError(string.Empty, msg);
                    LoadLookups();
                    return Page();
                }

                break;
            }

            case "Flowering":
            {
                // =========================
                // Load plant lifecycle
                // =========================

                var plant = await _db.Plants
                    .AsNoTracking()
                    .Where(p => p.PlantId == PlantId)
                    .Select(p => new { p.AcquisitionDate, p.EndDate })
                    .SingleAsync();

                var startDate = StartDate.Date;
                var endDate = EndDate?.Date;

                // =========================
                // StartDate validation
                // =========================

                // Rule 1 — not in future
                if (startDate > DateTime.Today)
                {
                    ModelState.AddModelError(nameof(StartDate),
                        "Start date cannot be in the future.");
                }

                // Rule 2 — not before acquisition
                if (plant.AcquisitionDate.HasValue &&
                    startDate < plant.AcquisitionDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(StartDate),
                        "Start date cannot be before the plant was acquired.");
                }

                // Rule 3 — not after plant end
                if (plant.EndDate.HasValue &&
                    startDate > plant.EndDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(StartDate),
                        "Start date cannot be after the plant has ended.");
                }

                // =========================
                // EndDate validation (if provided)
                // =========================

                if (endDate.HasValue)
                {
                    // Rule 4 — not before start
                    if (endDate.Value < startDate)
                    {
                        ModelState.AddModelError(nameof(EndDate),
                            "End date cannot be before start date.");
                    }

                    // Rule 5 — not in future
                    if (endDate.Value > DateTime.Today)
                    {
                        ModelState.AddModelError(nameof(EndDate),
                            "End date cannot be in the future.");
                    }

                    // Rule 6 — not after plant end
                    if (plant.EndDate.HasValue &&
                        endDate.Value > plant.EndDate.Value.Date)
                    {
                        ModelState.AddModelError(nameof(EndDate),
                            "End date cannot be after the plant has ended.");
                    }
                }

                // =========================
                // Stop adding an overlapping flowering
                // =========================
                if (ModelState.IsValid)
                {
                    var hasConflict = await _db.Flowering
                        .AnyAsync(f =>
                            f.PlantId == PlantId &&
                            f.IsActive &&
                            (
                                // Existing open flowering → always conflict
                                f.EndDate == null ||

                                // New open flowering (no EndDate provided)
                                (!endDate.HasValue &&
                                    f.EndDate != null &&
                                    startDate >= f.StartDate.Date &&
                                    startDate <= f.EndDate.Value.Date) ||

                                // New closed flowering overlaps existing closed flowering
                                (endDate.HasValue &&
                                    f.EndDate != null &&
                                    startDate <= f.EndDate.Value.Date &&
                                    f.StartDate.Date <= endDate.Value)
                            ));

                    if (hasConflict)
                    {
                        ModelState.AddModelError(string.Empty,
                            "This flowering overlaps an existing flowering period.");
                    }
                }

                // =========================
                // Stop if invalid
                // =========================

                if (!ModelState.IsValid)
                {
                    LoadLookups();
                    return Page();
                }

                // =========================
                // Save (unchanged logic)
                // =========================

                _db.Flowering.Add(new Flowering
                {
                    PlantId = PlantId,
                    StartDate = new DateTime(
									StartDate.Year,
									StartDate.Month,
									StartDate.Day,
									now.Hour,
									now.Minute,
									now.Second),
                    EndDate = EndDate.HasValue
									? new DateTime(
										EndDate.Value.Year,
										EndDate.Value.Month,
										EndDate.Value.Day,
										now.Hour,
										now.Minute,
										now.Second)
									: null,
                    SpikeCount = SpikeCount,
                    FlowerCount = FlowerCount,
                    FloweringNotes = EventDetails,
                    IsActive = true
                });

                await _db.SaveChangesAsync();

                break;
            }

            case "Repotting":
            {
                // =========================
                // Date validation (Repotting rules)
                // =========================

                var plant = await _db.Plants
                    .AsNoTracking()
                    .Where(p => p.PlantId == PlantId)
                    .Select(p => new { p.AcquisitionDate, p.EndDate })
                    .SingleAsync();

                var eventDate = EventDate.Date;

                // Rule 1 — cannot be in the future
                if (eventDate > DateTime.Today)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Repotting date cannot be in the future.");
                }

                // Rule 2 — cannot be before acquisition
                if (plant.AcquisitionDate.HasValue &&
                    eventDate < plant.AcquisitionDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Repotting date cannot be before the plant was acquired.");
                }

                // Rule 3 — cannot be after end
                if (plant.EndDate.HasValue &&
                    eventDate > plant.EndDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Repotting date cannot be after the plant has ended.");
                }

                // Rule 4 — growth medium must be selected
                if (!NewGrowthMediumId.HasValue)
                {
                    ModelState.AddModelError(nameof(NewGrowthMediumId),
                        "Please select a growth medium.");
                }

                if (!ModelState.IsValid)
                {
                    LoadLookups();
                    return Page();
                }

                // =========================
                // Save
                // =========================

                _db.Repotting.Add(new Repotting
                {
                    PlantId = PlantId,
                    RepotDate = new DateTime(
                        EventDate.Year,
                        EventDate.Month,
                        EventDate.Day,
                        now.Hour,
                        now.Minute,
                        now.Second),
                    OldGrowthMediumId = OldGrowthMediumId,
                    NewGrowthMediumId = NewGrowthMediumId,
                    OldMediumNotes = OldMediumNotes,
                    NewMediumNotes = NewMediumNotes,
                    PotSize = PotSize,
                    RepotReasonNotes = RepotReasonNotes,
                    RepottingNotes = RepottingNotes,
                    IsActive = true
                });

                await _db.SaveChangesAsync();

                break;
            }
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}