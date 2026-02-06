using System;
using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Models;

public class Flowering
{
    public int FloweringId { get; set; }

    public int PlantId { get; set; }

    [DataType(DataType.Date)]
    public DateTime StartDate { get; set; }

    [DataType(DataType.Date)]
    public DateTime? EndDate { get; set; }

    public int? SpikeCount { get; set; }

    public int? FlowerCount { get; set; }

    public string? FloweringNotes { get; set; }

    public DateTime CreatedDateTime { get; set; }

    public DateTime UpdatedDateTime { get; set; }

    public bool IsActive { get; set; } = true;
}
