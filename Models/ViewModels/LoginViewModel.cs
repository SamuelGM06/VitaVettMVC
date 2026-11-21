using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models.ViewModels;

public class LoginViewModel
{
    [Required(ErrorMessage = "La cédula es obligatoria.")]
    [Display(Name = "Cédula")]
    public string Cedula { get; set; } = "";

    [Required(ErrorMessage = "La contraseña es obligatoria.")]
    [DataType(DataType.Password)]
    public string Password { get; set; } = "";
}
