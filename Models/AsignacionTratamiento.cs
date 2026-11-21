using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

/// <summary>Medicamento o tratamiento asignado a una mascota (vigente o suspendido).</summary>
public class AsignacionTratamiento
{
    public int Id { get; set; }

    public int MascotaId { get; set; }
    public Mascota Mascota { get; set; } = null!;

    /// <summary>Debe ser un ItemClinico de tipo Medicamento o Tratamiento.</summary>
    public int ItemClinicoId { get; set; }
    public ItemClinico ItemClinico { get; set; } = null!;

    /// <summary>Autoría: veterinario que asignó el tratamiento.</summary>
    public int VeterinarioId { get; set; }
    public Veterinario Veterinario { get; set; } = null!;

    public DateOnly FechaInicio { get; set; }

    [MaxLength(500)]
    public string? Indicaciones { get; set; }

    /// <summary>Vigente = no suspendido.</summary>
    public bool Suspendido { get; set; }

    public DateOnly? FechaSuspension { get; set; }

    /// <summary>Autoría de la suspensión, si la hubo.</summary>
    public int? VeterinarioSuspensionId { get; set; }
    public Veterinario? VeterinarioSuspension { get; set; }
}
