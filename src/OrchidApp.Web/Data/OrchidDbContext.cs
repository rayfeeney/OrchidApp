using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Data;

public class OrchidDbContext : DbContext
{
    public OrchidDbContext(DbContextOptions<OrchidDbContext> options)
        : base(options)
    {
    }

    public DbSet<Genus> Genera => Set<Genus>();
    public DbSet<TaxonIdentity> TaxonIdentities => Set<TaxonIdentity>();
    public DbSet<Plant> Plants => Set<Plant>();
    public DbSet<PlantActiveSummary> PlantActiveSummaries => Set<PlantActiveSummary>();
    public DbSet<PlantCurrentLocation> PlantCurrentLocations => Set<PlantCurrentLocation>();
    public DbSet<PlantLifecycleEvent> PlantLifecycleHistory => Set<PlantLifecycleEvent>();
    public DbSet<PlantEvent> PlantEvent => Set<PlantEvent>();
    public DbSet<Location> Location => Set<Location>();
    public DbSet<Flowering> Flowering => Set<Flowering>();
    public DbSet<Repotting> Repotting => Set<Repotting>();
    public DbSet<PlantPhoto> PlantPhotos { get; set; }
    public DbSet<ObservationType> ObservationTypes { get; set; }


    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // =========================
        // Genus table mapping
        // =========================
        modelBuilder.Entity<Genus>(entity =>
        {
            entity.ToTable("genus");
            entity.HasKey(e => e.GenusId);

            entity.Property(e => e.GenusId)                 .HasColumnName("genusId");
            entity.Property(e => e.Name)                    .HasColumnName("genusName");
            entity.Property(e => e.Notes)                   .HasColumnName("genusNotes");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
        });
        
        // =========================
        // Taxon identity view mapping
        // =========================        
            modelBuilder.Entity<TaxonIdentity>(entity =>
        {
            entity.ToView("vtaxonidentity");
            entity.HasKey(e => e.TaxonId);

            entity.Property(e => e.TaxonId)                 .HasColumnName("taxonId");
            entity.Property(e => e.GenusId)                 .HasColumnName("genusId");
            entity.Property(e => e.GenusName)               .HasColumnName("genusName");
            entity.Property(e => e.SpeciesName)             .HasColumnName("speciesName");
            entity.Property(e => e.HybridName)              .HasColumnName("hybridName");
            entity.Property(e => e.DisplayName)             .HasColumnName("displayName");
            entity.Property(e => e.TaxonNotes)              .HasColumnName("taxonNotes");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
        });

        // =========================
        // Plant active view mapping
        // ========================= 
        modelBuilder.Entity<PlantActiveSummary>(entity =>
        {
            entity.ToView("vplantactivesummary");
            entity.HasKey(e => e.PlantId);

            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.TaxonId)                 .HasColumnName("taxonId");
            entity.Property(e => e.PlantTag)                .HasColumnName("plantTag");
            entity.Property(e => e.PlantName)               .HasColumnName("plantName");
            entity.Property(e => e.AcquisitionDate)         .HasColumnName("acquisitionDate");
            entity.Property(e => e.AcquisitionSource)       .HasColumnName("acquisitionSource");
            entity.Property(e => e.GenusName)               .HasColumnName("genusName");
            entity.Property(e => e.SpeciesName)             .HasColumnName("speciesName");
            entity.Property(e => e.HybridName)              .HasColumnName("hybridName");
            entity.Property(e => e.DisplayName)             .HasColumnName("displayName");
        });

        // =========================
        // Plant current location view mapping
        // =========================
        modelBuilder.Entity<PlantCurrentLocation>(entity =>
        {
            entity.ToView("vplantcurrentlocation");
            // Stable identity for EF (comes from plantlocationhistory)
            entity.HasNoKey();

            entity.Property(e => e.PlantLocationHistoryId)  .HasColumnName("plantLocationHistoryId");
            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.PlantTag)                .HasColumnName("plantTag");
            entity.Property(e => e.PlantName)               .HasColumnName("plantName");
            entity.Property(e => e.DisplayName)             .HasColumnName("displayName");
            entity.Property(e => e.TaxonId)                 .HasColumnName("taxonId");
            entity.Property(e => e.LocationId)              .HasColumnName("locationId");
            entity.Property(e => e.LocationName)            .HasColumnName("locationName");
            entity.Property(e => e.LocationTypeCode)        .HasColumnName("locationTypeCode");
            entity.Property(e => e.LocationStartDateTime)   .HasColumnName("locationStartDateTime");
        });

        // =========================
        // Plant lifecycle event mapping
        // =========================
        modelBuilder.Entity<PlantLifecycleEvent>(entity =>
        {
            entity.ToView("vplantlifecyclehistory");
            entity.HasNoKey();
            
            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.EventDateTime)           .HasColumnName("eventDateTime");
            entity.Property(e => e.EventType)               .HasColumnName("eventType");
            entity.Property(e => e.EventSummary)            .HasColumnName("eventSummary");
            entity.Property(e => e.SourceTable)             .HasColumnName("sourceTable");
            entity.Property(e => e.SourceId)                .HasColumnName("sourceId");
        });

        // =========================
        // Plant event mapping
        // =========================
        modelBuilder.Entity<PlantEvent>(entity =>
        {
            entity.ToTable("plantevent");
            entity.HasKey(e => e.PlantEventId);

            entity.Property(e => e.PlantEventId)            .HasColumnName("plantEventId");
            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.ObservationTypeId)       .HasColumnName("observationTypeId");
            entity.Property(e => e.EventDateTime)           .HasColumnName("eventDateTime");
            entity.Property(e => e.EventDetails)            .HasColumnName("eventDetails");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
            entity.Property(e => e.UpdatedDateTime)         .HasColumnName("updatedDateTime");
        });
        modelBuilder.Entity<PlantPhoto>()                   .ToTable("plantphoto");
        // =========================
        // Location table mapping
        // =========================
        modelBuilder.Entity<Location>(entity =>
        {
            entity.ToTable("location");
            entity.HasKey(e => e.LocationId);

            entity.Property(e => e.LocationId)              .HasColumnName("locationId");
            entity.Property(e => e.LocationName)            .HasColumnName("locationName");
            entity.Property(e => e.LocationTypeCode)        .HasColumnName("locationTypeCode");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
        });

        // =========================
        // Flowering table mapping
        // =========================
        modelBuilder.Entity<Flowering>(entity =>
        {
            entity.ToTable("flowering");
            entity.HasKey(e => e.FloweringId);

            entity.Property(e => e.FloweringId)             .HasColumnName("floweringId");
            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.StartDate)               .HasColumnName("startDate");
            entity.Property(e => e.EndDate)                 .HasColumnName("endDate");
            entity.Property(e => e.SpikeCount)              .HasColumnName("spikeCount");
            entity.Property(e => e.FlowerCount)             .HasColumnName("flowerCount");
            entity.Property(e => e.FloweringNotes)          .HasColumnName("floweringNotes");
            entity.Property(e => e.CreatedDateTime)         .HasColumnName("createdDateTime");
            entity.Property(e => e.UpdatedDateTime)         .HasColumnName("updatedDateTime");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
        });

        // =========================
        // Repotting table mapping
        // =========================
        modelBuilder.Entity<Repotting>(entity =>
        {
            entity.ToTable("repotting");
            entity.HasKey(e => e.RepottingId);

            entity.Property(e => e.RepottingId)             .HasColumnName("repottingId");
            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.RepotDate)               .HasColumnName("repotDate");
            entity.Property(e => e.OldMediumCode)           .HasColumnName("oldMediumCode");
            entity.Property(e => e.NewMediumCode)           .HasColumnName("newMediumCode");
            entity.Property(e => e.RepotReasonCode)         .HasColumnName("repotReasonCode");
            entity.Property(e => e.OldMediumNotes)          .HasColumnName("oldMediumNotes");
            entity.Property(e => e.NewMediumNotes)          .HasColumnName("newMediumNotes");
            entity.Property(e => e.PotSize)                 .HasColumnName("potSize");
            entity.Property(e => e.RepotReasonNotes)        .HasColumnName("repotReasonNotes");
            entity.Property(e => e.RepottingNotes)          .HasColumnName("repottingNotes");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
        });

        // =========================
        // Plant table mapping
        // =========================
        modelBuilder.Entity<Plant>(entity =>
        {
            entity.ToTable("plant");
            entity.HasKey(e => e.PlantId);

            entity.Property(e => e.PlantId)                 .HasColumnName("plantId");
            entity.Property(e => e.TaxonId)                 .HasColumnName("taxonId");
            entity.Property(e => e.PlantTag)                .HasColumnName("plantTag");
            entity.Property(e => e.PlantName)               .HasColumnName("plantName");
            entity.Property(e => e.AcquisitionDate)         .HasColumnName("acquisitionDate");
            entity.Property(e => e.AcquisitionSource)       .HasColumnName("acquisitionSource");
            entity.Property(e => e.IsActive)                .HasColumnName("isActive");
            entity.Property(e => e.EndReasonCode)           .HasColumnName("endReasonCode");
            entity.Property(e => e.EndDate)                 .HasColumnName("endDate");
            entity.Property(e => e.EndNotes)                .HasColumnName("endNotes");
            entity.Property(e => e.PlantNotes)              .HasColumnName("plantNotes");
            entity.Property(e => e.CreatedDateTime)         .HasColumnName("createdDateTime")
                                                            .ValueGeneratedOnAdd();
            entity.Property(e => e.UpdatedDateTime)         .HasColumnName("updatedDateTime")
                                                            .ValueGeneratedOnAddOrUpdate();
        });

        {
            modelBuilder.Entity<ObservationType>()
                .ToTable("observationtype");
        }
        }
}
