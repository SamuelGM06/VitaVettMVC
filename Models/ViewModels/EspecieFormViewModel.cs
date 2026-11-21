using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models.ViewModels;

public class EspecieFormViewModel
{
    public int Id { get; set; }

    [Required(ErrorMessage = "El nombre de la especie es obligatorio.")]
    [StringLength(80)]
    public string Nombre { get; set; } = "";
}
