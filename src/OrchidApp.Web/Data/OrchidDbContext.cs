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
    public DbSet<PlantActiveSummary> PlantActiveSummaries => Set<PlantActiveSummary>();
    public DbSet<PlantCurrentLocation> PlantCurrentLocations => Set<PlantCurrentLocation>();



    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // =========================
        // Genus table mapping
        // =========================
        modelBuilder.Entity<Genus>(entity =>
        {
            entity.ToTable("genus");
            entity.HasKey(e => e.GenusId);

            entity.Property(e => e.GenusId)
                  .HasColumnName("genusId");

            entity.Property(e => e.Name)
                  .HasColumnName("genusName");

            entity.Property(e => e.Notes)
                  .HasColumnName("genusNotes");

            entity.Property(e => e.IsActive)
                  .HasColumnName("isActive");
        });
        
        // =========================
        // Taxon identity view mapping
        // =========================        
            modelBuilder.Entity<TaxonIdentity>(entity =>
        {
            entity.ToView("vTaxonIdentity");

            entity.HasKey(e => e.TaxonId);

            entity.Property(e => e.TaxonId)
                .HasColumnName("taxonId");

            entity.Property(e => e.GenusId)
                .HasColumnName("genusId");

            entity.Property(e => e.GenusName)
                .HasColumnName("genusName");

            entity.Property(e => e.SpeciesName)
                .HasColumnName("speciesName");

            entity.Property(e => e.HybridName)
                .HasColumnName("hybridName");

            entity.Property(e => e.DisplayName)
                .HasColumnName("displayName");

            entity.Property(e => e.TaxonNotes)
                .HasColumnName("taxonNotes");

            entity.Property(e => e.IsActive)
                .HasColumnName("isActive");
        });

        // =========================
        // Plant active view mapping
        // ========================= 
        modelBuilder.Entity<PlantActiveSummary>(entity =>
        {
            entity.ToView("vPlantActiveSummary");
            entity.HasKey(e => e.PlantId);

            entity.Property(e => e.PlantId).HasColumnName("plantId");
            entity.Property(e => e.TaxonId).HasColumnName("taxonId");

            entity.Property(e => e.PlantTag).HasColumnName("plantTag");
            entity.Property(e => e.PlantName).HasColumnName("plantName");

            entity.Property(e => e.AcquisitionDate)
                .HasColumnName("acquisitionDate");

            entity.Property(e => e.AcquisitionSource)
                .HasColumnName("acquisitionSource");

            entity.Property(e => e.GenusName).HasColumnName("genusName");
            entity.Property(e => e.SpeciesName).HasColumnName("speciesName");
            entity.Property(e => e.HybridName).HasColumnName("hybridName");

            entity.Property(e => e.DisplayName).HasColumnName("displayName");

        });
        // =========================
        // Plant current location view mapping
        // =========================
        modelBuilder.Entity<PlantCurrentLocation>(entity =>
        {
            entity.ToView("vplantcurrentlocation");
            entity.HasKey(e => e.PlantId);

            entity.Property(e => e.PlantId).HasColumnName("plantId");
            entity.Property(e => e.PlantTag).HasColumnName("plantTag");
            entity.Property(e => e.DisplayName).HasColumnName("displayName");
            entity.Property(e => e.LocationName).HasColumnName("locationName");
        });

    }
}
