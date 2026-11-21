using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

/// <summary>Resultado de examen (PDF o imagen) almacenado en la BD.</summary>
public class ExamenArchivo
{
    public int Id { get; set; }

    public int MascotaId { get; set; }
    public Mascota Mascota { get; set; } = null!;

    /// <summary>Autoría: veterinario que subió el examen.</summary>
    public int VeterinarioId { get; set; }
    public Veterinario Veterinario { get; set; } = null!;

    [Required, MaxLength(300)]
    public string Descripcion { get; set; } = "";

    [Required]
    public byte[] Contenido { get; set; } = [];

    [Required, MaxLength(100)]
    public string ContentType { get; set; } = "";

    [Required, MaxLength(260)]
    public string NombreArchivo { get; set; } = "";

    public DateTime FechaSubida { get; set; } = DateTime.UtcNow;
}
