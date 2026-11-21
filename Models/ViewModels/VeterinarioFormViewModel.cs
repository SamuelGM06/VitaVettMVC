using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models.ViewModels;

public class VeterinarioFormViewModel
{
    public int Id { get; set; }

    [Required(ErrorMessage = "La cédula es obligatoria.")]
    [StringLength(20)]
    [Display(Name = "Cédula")]
    public string Cedula { get; set; } = "";

    [Required(ErrorMessage = "El nombre es obligatorio.")]
    [StringLength(100)]
    public string Nombre { get; set; } = "";

    [Required(ErrorMessage = "Los apellidos son obligatorios.")]
    [StringLength(150)]
    public string Apellidos { get; set; } = "";

    [Required(ErrorMessage = "El correo es obligatorio.")]
    [EmailAddress(ErrorMessage = "Ingrese un correo válido.")]
    [StringLength(256)]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "El número de colegiado es obligatorio.")]
    [StringLength(50)]
    [Display(Name = "Número de colegiado")]
    public string NumeroColegiado { get; set; } = "";

    /// <summary>Solo se usa al crear. Se valida en el controlador (obligatoria al crear).</summary>
    [StringLength(100, MinimumLength = 8, ErrorMessage = "La contraseña debe tener al menos 8 caracteres.")]
    [DataType(DataType.Password)]
    public string? Password { get; set; }

    [Display(Name = "Foto (JPG o PNG, máx. 2 MB)")]
    public IFormFile? Foto { get; set; }
}
