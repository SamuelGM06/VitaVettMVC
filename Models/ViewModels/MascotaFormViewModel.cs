using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace VitaVettMVC.Models.ViewModels;

public class MascotaFormViewModel
{
    public int Id { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio.")]
    [StringLength(100)]
    public string Nombre { get; set; } = "";

    [Required(ErrorMessage = "Seleccione una especie.")]
    [Display(Name = "Especie")]
    public int? EspecieId { get; set; }

    [Display(Name = "Raza")]
    public int? RazaId { get; set; }

    [Required(ErrorMessage = "Seleccione el dueño.")]
    [Display(Name = "Dueño")]
    public int? DuenoId { get; set; }

    [DataType(DataType.Date)]
    [Display(Name = "Fecha de nacimiento")]
    public DateOnly? FechaNacimiento { get; set; }

    [StringLength(10)]
    public string? Sexo { get; set; }

    [Display(Name = "Foto (JPG o PNG, máx. 2 MB)")]
    public IFormFile? Foto { get; set; }

    [ValidateNever]
    public IEnumerable<Especie> Especies { get; set; } = new List<Especie>();

    [ValidateNever]
    public IEnumerable<Raza> Razas { get; set; } = new List<Raza>();

    [ValidateNever]
    public IEnumerable<Usuario> Duenos { get; set; } = new List<Usuario>();
}
