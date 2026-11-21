using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

[Authorize(Roles = "Administrador")]
public class RazasController(AppDbContext db) : Controller
{
    private const string DuplicadaMessage = "Ya existe una raza con ese nombre en la especie seleccionada.";
    private const string EnUsoMessage = "No se puede eliminar esta raza porque tiene mascotas asociadas.";
    private const string CambioEspecieMessage =
        "No se puede cambiar la especie de una raza que ya tiene mascotas asociadas.";

    public async Task<IActionResult> Index()
    {
        var razas = await db.Razas
            .Include(r => r.Especie)
            .OrderBy(r => r.Especie.Nombre)
            .ThenBy(r => r.Nombre)
            .ToListAsync();
        return View(razas);
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        return View(new RazaFormViewModel { Especies = await GetEspeciesAsync() });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(RazaFormViewModel model)
    {
        if (!ModelState.IsValid)
        {
            model.Especies = await GetEspeciesAsync();
            return View(model);
        }

        var especieId = model.EspecieId!.Value;
        var nombre = model.Nombre.Trim();

        if (!await db.Especies.AnyAsync(e => e.Id == especieId))
        {
            ModelState.AddModelError(nameof(model.EspecieId), "La especie seleccionada no existe.");
        }
        else if (await db.Razas.AnyAsync(r => r.EspecieId == especieId && r.Nombre == nombre))
        {
            ModelState.AddModelError(nameof(model.Nombre), DuplicadaMessage);
        }

        if (!ModelState.IsValid)
        {
            model.Especies = await GetEspeciesAsync();
            return View(model);
        }

        db.Razas.Add(new Raza { EspecieId = especieId, Nombre = nombre });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Raza creada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var raza = await db.Razas.FindAsync(id);
        if (raza is null)
        {
            return NotFound();
        }

        return View(new RazaFormViewModel
        {
            Id = raza.Id,
            EspecieId = raza.EspecieId,
            Nombre = raza.Nombre,
            Especies = await GetEspeciesAsync()
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, RazaFormViewModel model)
    {
        var raza = await db.Razas.FindAsync(id);
        if (raza is null)
        {
            return NotFound();
        }

        model.Id = id;

        if (!ModelState.IsValid)
        {
            model.Especies = await GetEspeciesAsync();
            return View(model);
        }

        var especieId = model.EspecieId!.Value;
        var nombre = model.Nombre.Trim();

        if (especieId != raza.EspecieId &&
            await db.Mascotas.AnyAsync(m => m.RazaId == id))
        {
            ModelState.AddModelError(nameof(model.EspecieId), CambioEspecieMessage);
        }
        else if (await db.Razas.AnyAsync(r => r.EspecieId == especieId && r.Nombre == nombre && r.Id != id))
        {
            ModelState.AddModelError(nameof(model.Nombre), DuplicadaMessage);
        }

        if (!ModelState.IsValid)
        {
            model.Especies = await GetEspeciesAsync();
            return View(model);
        }

        raza.EspecieId = especieId;
        raza.Nombre = nombre;
        await db.SaveChangesAsync();
        TempData["Exito"] = "Raza actualizada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id)
    {
        var raza = await db.Razas.Include(r => r.Especie).FirstOrDefaultAsync(r => r.Id == id);
        if (raza is null)
        {
            return NotFound();
        }

        ViewBag.MascotasCount = await db.Mascotas.CountAsync(m => m.RazaId == id);
        return View(raza);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var raza = await db.Razas.FindAsync(id);
        if (raza is null)
        {
            return NotFound();
        }

        // Regla de integridad: no se borra una raza con mascotas.
        if (await db.Mascotas.AnyAsync(m => m.RazaId == id))
        {
            TempData["Error"] = EnUsoMessage;
            return RedirectToAction(nameof(Index));
        }

        db.Razas.Remove(raza);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Raza eliminada.";
        return RedirectToAction(nameof(Index));
    }

    private Task<List<Especie>> GetEspeciesAsync()
    {
        return db.Especies.OrderBy(e => e.Nombre).ToListAsync();
    }
}
