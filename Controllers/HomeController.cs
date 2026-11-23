using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;

namespace VitaVettMVC.Controllers;

[Authorize]
public class HomeController(AppDbContext db) : Controller
{
    public async Task<IActionResult> Index()
    {
        if (User.IsInRole("Administrador") || User.IsInRole("Veterinario"))
        {
            var hoy = DateOnly.FromDateTime(DateTime.Today);

            // Vencida = la aplicación más reciente de esa vacuna para esa mascota tiene la próxima dosis en el pasado.
            var vencidas = db.AplicacionesVacuna.Where(a => a.ProximaDosis < hoy
                && !db.AplicacionesVacuna.Any(b => b.MascotaId == a.MascotaId
                                                   && b.ItemClinicoId == a.ItemClinicoId
                                                   && b.FechaAplicacion > a.FechaAplicacion));

            ViewBag.TotalMascotas = await db.Mascotas.CountAsync();
            ViewBag.TotalVencidas = await vencidas.CountAsync();
            ViewBag.TotalTratamientos = await db.AsignacionesTratamiento.CountAsync(t => !t.Suspendido);
            ViewBag.Vencidas = await vencidas
                .Include(a => a.Mascota)
                .Include(a => a.ItemClinico)
                .OrderBy(a => a.ProximaDosis)
                .Take(5)
                .ToListAsync();
        }

        return View();
    }

    public IActionResult Privacy()
    {
        return View();
    }

    [AllowAnonymous]
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
