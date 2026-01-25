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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
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
    }
}
