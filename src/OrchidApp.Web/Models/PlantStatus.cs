using System;

namespace OrchidApp.Web.Models;

public class PlantStatus
{
    public int PlantId { get; set; }

    public string? PlantTag { get; set; }
    public string? DisplayName { get; set; }

    public DateTime? AcquisitionDate { get; set; }
    public string? AcquisitionSource { get; set; }

    public string? LocationName { get; set; }

    public DateTime? LastFloweringDate { get; set; }

    public DateTime? LastRepotDate { get; set; }
    public string? CurrentGrowthMediumName { get; set; }

    public DateTime? LastFeedDate { get; set; }
    public string? LastFeedTypeDisplayName { get; set; }

    public bool TaxonIsActive { get; set; }
    public bool GenusIsActive { get; set; }
}