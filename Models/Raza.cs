using System.ComponentModel.DataAnnotations;

namespace VitaVettMVC.Models;

public class Raza
{
    public int Id { get; set; }

    public int EspecieId { get; set; }
    public Especie Especie { get; set; } = null!;

    [Required, MaxLength(80)]
    public string Nombre { get; set; } = "";

    public ICollection<Mascota> Mascotas { get; set; } = new List<Mascota>();
}
