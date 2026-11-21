using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

public class Mascota
{
    public int Id { get; set; }

    [Required, MaxLength(100)]
    public string Nombre { get; set; } = "";

    public int EspecieId { get; set; }
    public Especie Especie { get; set; } = null!;

    public int? RazaId { get; set; }
    public Raza? Raza { get; set; }

    /// <summary>Usuario con rol Dueno.</summary>
    public int DuenoId { get; set; }
    public Usuario Dueno { get; set; } = null!;

    public DateOnly? FechaNacimiento { get; set; }

    [MaxLength(10)]
    public string? Sexo { get; set; }

    public byte[]? Foto { get; set; }

    [MaxLength(100)]
    public string? FotoContentType { get; set; }

    public ICollection<AplicacionVacuna> AplicacionesVacuna { get; set; } = new List<AplicacionVacuna>();
    public ICollection<AsignacionTratamiento> Tratamientos { get; set; } = new List<AsignacionTratamiento>();
    public ICollection<ExamenArchivo> Examenes { get; set; } = new List<ExamenArchivo>();
    public ICollection<NotaHistorial> Notas { get; set; } = new List<NotaHistorial>();
}
