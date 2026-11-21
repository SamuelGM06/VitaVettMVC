using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

[Authorize(Roles = "Administrador")]
public class EspeciesController(AppDbContext db) : Controller
{
    private const string EnUsoMessage =
        "No se puede eliminar esta especie porque tiene razas o mascotas asociadas.";

    public async Task<IActionResult> Index()
    {
        var especies = await db.Especies.OrderBy(e => e.Nombre).ToListAsync();
        return View(especies);
    }

    [HttpGet]
    public IActionResult Create()
    {
        return View(new EspecieFormViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(EspecieFormViewModel model)
    {
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var nombre = model.Nombre.Trim();
        if (await db.Especies.AnyAsync(e => e.Nombre == nombre))
        {
            ModelState.AddModelError(nameof(model.Nombre), "Ya existe una especie con ese nombre.");
            return View(model);
        }

        db.Especies.Add(new Especie { Nombre = nombre });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Especie creada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var especie = await db.Especies.FindAsync(id);
        if (especie is null)
        {
            return NotFound();
        }

        return View(new EspecieFormViewModel { Id = especie.Id, Nombre = especie.Nombre });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, EspecieFormViewModel model)
    {
        var especie = await db.Especies.FindAsync(id);
        if (especie is null)
        {
            return NotFound();
        }

        if (!ModelState.IsValid)
        {
            model.Id = id;
            return View(model);
        }

        var nombre = model.Nombre.Trim();
        if (await db.Especies.AnyAsync(e => e.Nombre == nombre && e.Id != id))
        {
            ModelState.AddModelError(nameof(model.Nombre), "Ya existe una especie con ese nombre.");
            model.Id = id;
            return View(model);
        }

        especie.Nombre = nombre;
        await db.SaveChangesAsync();
        TempData["Exito"] = "Especie actualizada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id)
    {
        var especie = await db.Especies.FindAsync(id);
        if (especie is null)
        {
            return NotFound();
        }

        ViewBag.RazasCount = await db.Razas.CountAsync(r => r.EspecieId == id);
        ViewBag.MascotasCount = await db.Mascotas.CountAsync(m => m.EspecieId == id);
        return View(especie);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var especie = await db.Especies.FindAsync(id);
        if (especie is null)
        {
            return NotFound();
        }

        // Regla de integridad: no se borra nada que esté en uso.
        var enUso = await db.Razas.AnyAsync(r => r.EspecieId == id)
                    || await db.Mascotas.AnyAsync(m => m.EspecieId == id);
        if (enUso)
        {
            TempData["Error"] = EnUsoMessage;
            return RedirectToAction(nameof(Index));
        }

        db.Especies.Remove(especie);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Especie eliminada.";
        return RedirectToAction(nameof(Index));
    }
}
