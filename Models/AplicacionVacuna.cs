namespace VitaVettMVC.Models;

public class AplicacionVacuna
{
    public int Id { get; set; }

    public int MascotaId { get; set; }
    public Mascota Mascota { get; set; } = null!;

    /// <summary>Debe ser un ItemClinico de tipo Vacuna.</summary>
    public int ItemClinicoId { get; set; }
    public ItemClinico ItemClinico { get; set; } = null!;

    /// <summary>Autoría: veterinario que aplicó la vacuna.</summary>
    public int VeterinarioId { get; set; }
    public Veterinario Veterinario { get; set; } = null!;

    public DateOnly FechaAplicacion { get; set; }

    /// <summary>Próxima dosis; base de la alerta de vacunas vencidas en Flutter.</summary>
    public DateOnly? ProximaDosis { get; set; }
}
