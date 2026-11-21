using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace VitaVettMVC.Models.ViewModels;

public class RazaFormViewModel
{
    public int Id { get; set; }

    [Required(ErrorMessage = "Seleccione una especie.")]
    [Display(Name = "Especie")]
    public int? EspecieId { get; set; }

    [Required(ErrorMessage = "El nombre de la raza es obligatorio.")]
    [StringLength(80)]
    public string Nombre { get; set; } = "";

    [ValidateNever]
    public IEnumerable<Especie> Especies { get; set; } = new List<Especie>();
}
