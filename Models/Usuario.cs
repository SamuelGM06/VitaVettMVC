using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

public class Usuario
{
    public int Id { get; set; }

    [Required, MaxLength(20)]
    public string Cedula { get; set; } = "";

    [Required, MaxLength(100)]
    public string Nombre { get; set; } = "";

    [Required, MaxLength(150)]
    public string Apellidos { get; set; } = "";

    [Required, MaxLength(256)]
    [EmailAddress]
    public string Email { get; set; } = "";

    [Required]
    public string PasswordHash { get; set; } = "";

    public RolUsuario Rol { get; set; }

    /// <summary>Un usuario bloqueado no puede iniciar sesión ni usar la API.</summary>
    public bool Bloqueado { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public Veterinario? Veterinario { get; set; }
    public ICollection<Mascota> Mascotas { get; set; } = new List<Mascota>();
}
