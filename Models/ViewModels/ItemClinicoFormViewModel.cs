using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models.ViewModels;

public class ItemClinicoFormViewModel
{
    public int Id { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio.")]
    [StringLength(120)]
    public string Nombre { get; set; } = "";

    [Required(ErrorMessage = "Seleccione un tipo.")]
    public TipoItemClinico? Tipo { get; set; }

    [StringLength(500)]
    public string? Descripcion { get; set; }

    public bool Activo { get; set; } = true;
}
