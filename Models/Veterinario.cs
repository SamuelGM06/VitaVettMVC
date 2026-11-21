using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

/// <summary>Perfil clínico de un Usuario con rol Veterinario (relación 1:1).</summary>
public class Veterinario
{
    public int Id { get; set; }

    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    [Required, MaxLength(50)]
    public string NumeroColegiado { get; set; } = "";

    /// <summary>Fotografía guardada en la BD (decisión 4 del modelo).</summary>
    public byte[]? Foto { get; set; }

    [MaxLength(100)]
    public string? FotoContentType { get; set; }
}
