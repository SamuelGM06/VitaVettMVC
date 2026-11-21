using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

/// <summary>
/// Nota del historial clínico. Es inmutable: la aplicación no expone edición ni borrado.
/// </summary>
public class NotaHistorial
{
    public int Id { get; set; }

    public int MascotaId { get; set; }
    public Mascota Mascota { get; set; } = null!;

    /// <summary>Autoría: veterinario que escribió la nota.</summary>
    public int VeterinarioId { get; set; }
    public Veterinario Veterinario { get; set; } = null!;

    /// <summary>HTML del texto enriquecido; debe sanitizarse antes de guardarse.</summary>
    [Required]
    public string Contenido { get; set; } = "";

    public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;
}
