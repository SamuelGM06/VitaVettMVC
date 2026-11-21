using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

/// <summary>Catálogo clínico: medicamentos, tratamientos y vacunas.</summary>
public class ItemClinico
{
    public int Id { get; set; }

    [Required, MaxLength(120)]
    public string Nombre { get; set; } = "";

    public TipoItemClinico Tipo { get; set; }

    [MaxLength(500)]
    public string? Descripcion { get; set; }

    /// <summary>Permite retirar un ítem del catálogo sin borrarlo si ya está en uso.</summary>
    public bool Activo { get; set; } = true;
}
