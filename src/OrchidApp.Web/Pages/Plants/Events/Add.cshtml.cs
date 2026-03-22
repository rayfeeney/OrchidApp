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
    private readonly IStoredProcedureExecutor _sp;
    private readonly ILogger<AddModel> _logger;

    public AddModel(
        OrchidDbContext db,
        ObservationTypeResolver resolver,
        PhotoPipeline photoPipeline,
        IStoredProcedureExecutor sp,
        ILogger<AddModel> logger)
    {
        _db = db;
        _resolver = resolver;
        _photoPipeline = photoPipeline;
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
                    break;

                case "feedGrowth":
                    EventDetails = "Fed with growth food";
                    break;

                case "feedBloom":
                    EventDetails = "Fed with bloom food";
                    break;
            }

            ModelState.Remove(nameof(EventDetails));
            ModelState.Remove(nameof(ShowPhotoSection));

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

                if (!hasPhotos && string.IsNullOrWhiteSpace(EventDetails))
                {
                    ModelState.AddModelError(nameof(EventDetails),
                        "Please enter some notes or add a photo.");
                }

                if (!ModelState.IsValid)
                {
                    LoadLookups();
                    return Page();
                }

                var typeCode = hasPhotos ? "OBS_PHOTO" : "OBS_NOTE";
                var observationTypeId = await _resolver.GetIdAsync(typeCode);

                var uploadsRoot = "/opt/orchidapp/uploads";
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
                                await using var stream = file.OpenReadStream();

                                result = await _photoPipeline.ProcessAndSaveAsync(
                                    stream,
                                    PlantId,
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

                            savedRelativePaths.Add(result.RelativePath);

                            var photo = new PlantPhoto
                            {
                                PlantEventId = observation.PlantEventId,
                                PlantId = PlantId,
                                FileName = file.FileName,
                                FilePath = result.RelativePath,
                                MimeType = result.MimeType,
                                IsHero = !heroExists,
                                IsActive = true,
                                CreatedDateTime = DateTime.Now
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
                try
                {

                    if (!LocationId.HasValue)
                    {
                        ModelState.AddModelError(nameof(LocationId),
                            "Please select a location.");

                        LoadLookups();
                        return Page();
                    }

                    await _sp.QueryListAsync<object>(
                        "spMovePlantToLocation",
                        new StoredProcedureParameter("pPlantId", PlantId),
                        new StoredProcedureParameter("pLocationId", LocationId.Value),
                        new StoredProcedureParameter("pStartDate", EventDate.Date),
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

            case "Flowering":
                if (EndDate.HasValue && EndDate < StartDate)
                {
                    ModelState.AddModelError(string.Empty,
                        "End date cannot be before start date.");
                    LoadLookups();
                    return Page();
                }

                _db.Flowering.Add(new Flowering
                {
                    PlantId = PlantId,
                    StartDate = StartDate.Date,
                    EndDate = EndDate?.Date,
                    SpikeCount = SpikeCount,
                    FlowerCount = FlowerCount,
                    FloweringNotes = EventDetails,
                    IsActive = true
                });

                await _db.SaveChangesAsync();
                break;

            case "Repotting":
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

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}