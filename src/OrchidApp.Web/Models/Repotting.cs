using System;

namespace OrchidApp.Web.Models;

public class Repotting
{
    public int RepottingId { get; set; }

    public int PlantId { get; set; }

    public DateTime RepotDate { get; set; }

    // Codes intentionally present but unused for now
    public string? OldMediumCode { get; set; }
    public string? NewMediumCode { get; set; }
    public string? RepotReasonCode { get; set; }

    public string? OldMediumNotes { get; set; }
    public string? NewMediumNotes { get; set; }

    public string? PotSize { get; set; }

    public string? RepotReasonNotes { get; set; }

    public string? RepottingNotes { get; set; }

    public bool IsActive { get; set; }
}
