using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Models;

namespace VitaVettMVC.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<Veterinario> Veterinarios => Set<Veterinario>();
    public DbSet<Especie> Especies => Set<Especie>();
    public DbSet<Raza> Razas => Set<Raza>();
    public DbSet<ItemClinico> ItemsClinicos => Set<ItemClinico>();
    public DbSet<Mascota> Mascotas => Set<Mascota>();
    public DbSet<AplicacionVacuna> AplicacionesVacuna => Set<AplicacionVacuna>();
    public DbSet<AsignacionTratamiento> AsignacionesTratamiento => Set<AsignacionTratamiento>();
    public DbSet<ExamenArchivo> Examenes => Set<ExamenArchivo>();
    public DbSet<NotaHistorial> NotasHistorial => Set<NotaHistorial>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Enums guardados como texto para leeerlo mejor
        modelBuilder.Entity<Usuario>()
            .Property(u => u.Rol)
            .HasConversion<string>()
            .HasMaxLength(20);

        modelBuilder.Entity<ItemClinico>()
            .Property(i => i.Tipo)
            .HasConversion<string>()
            .HasMaxLength(20);

        // Índices únicos.
        modelBuilder.Entity<Usuario>().HasIndex(u => u.Cedula).IsUnique();
        modelBuilder.Entity<Usuario>().HasIndex(u => u.Email).IsUnique();
        modelBuilder.Entity<Veterinario>().HasIndex(v => v.UsuarioId).IsUnique();
        modelBuilder.Entity<Veterinario>().HasIndex(v => v.NumeroColegiado).IsUnique();
        modelBuilder.Entity<Especie>().HasIndex(e => e.Nombre).IsUnique();
        modelBuilder.Entity<Raza>().HasIndex(r => new { r.EspecieId, r.Nombre }).IsUnique();
        modelBuilder.Entity<ItemClinico>().HasIndex(i => new { i.Tipo, i.Nombre }).IsUnique();

        // Regla de integridad del enunciado: ninguna relación puede borrar en cascada.
        // Borrar algo en uso queda bloqueado por la BD (DeleteBehavior.Restrict).
        foreach (var foreignKey in modelBuilder.Model.GetEntityTypes()
                     .SelectMany(t => t.GetForeignKeys()))
        {
            foreignKey.DeleteBehavior = DeleteBehavior.Restrict;
        }
    }
}
