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
    }
}
