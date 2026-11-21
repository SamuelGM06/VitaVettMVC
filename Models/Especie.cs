using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

public class Especie
{
    public int Id { get; set; }

    [Required, MaxLength(80)]
    public string Nombre { get; set; } = "";

    public ICollection<Raza> Razas { get; set; } = new List<Raza>();
    public ICollection<Mascota> Mascotas { get; set; } = new List<Mascota>();
}
