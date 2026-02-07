namespace OrchidApp.Web.Models;

public class Plant
{
    public int PlantId { get; set; }

    public int TaxonId { get; set; }

    public string? PlantTag { get; set; }
    public string? PlantName { get; set; }

    public DateOnly? AcquisitionDate { get; set; }
    public string? AcquisitionSource { get; set; }

    public bool IsActive { get; set; }

    public string? EndReasonCode { get; set; }
    public DateOnly? EndDate { get; set; }
    public string? EndNotes { get; set; }

    public string? PlantNotes { get; set; }

    public DateTime CreatedDateTime { get; set; }
    public DateTime UpdatedDateTime { get; set; }
}
