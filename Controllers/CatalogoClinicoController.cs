using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

[Authorize(Roles = "Administrador")]
public class CatalogoClinicoController(AppDbContext db) : Controller
{
    private const string DuplicadoMessage = "Ya existe un ítem con ese nombre y tipo.";
    private const string EnUsoMessage =
        "No se puede eliminar este ítem porque está en uso en expedientes. Puede desactivarlo en su lugar.";
    private const string CambioTipoMessage =
        "No se puede cambiar el tipo de un ítem que ya está en uso.";

    public async Task<IActionResult> Index(TipoItemClinico? tipo)
    {
        var query = db.ItemsClinicos.AsQueryable();
        if (tipo.HasValue)
        {
            query = query.Where(i => i.Tipo == tipo.Value);
        }

        var items = await query.OrderBy(i => i.Tipo).ThenBy(i => i.Nombre).ToListAsync();
        ViewBag.TipoSeleccionado = tipo;
        return View(items);
    }

    [HttpGet]
    public IActionResult Create()
    {
        return View(new ItemClinicoFormViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(ItemClinicoFormViewModel model)
    {
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var nombre = model.Nombre.Trim();
        var tipo = model.Tipo!.Value;

        if (await db.ItemsClinicos.AnyAsync(i => i.Tipo == tipo && i.Nombre == nombre))
        {
            ModelState.AddModelError(nameof(model.Nombre), DuplicadoMessage);
            return View(model);
        }

        db.ItemsClinicos.Add(new ItemClinico
        {
            Nombre = nombre,
            Tipo = tipo,
            Descripcion = string.IsNullOrWhiteSpace(model.Descripcion) ? null : model.Descripcion.Trim(),
            Activo = model.Activo
        });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Ítem creado.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var item = await db.ItemsClinicos.FindAsync(id);
        if (item is null)
        {
            return NotFound();
        }

        return View(new ItemClinicoFormViewModel
        {
            Id = item.Id,
            Nombre = item.Nombre,
            Tipo = item.Tipo,
            Descripcion = item.Descripcion,
            Activo = item.Activo
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, ItemClinicoFormViewModel model)
    {
        var item = await db.ItemsClinicos.FindAsync(id);
        if (item is null)
        {
            return NotFound();
        }

        model.Id = id;

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var nombre = model.Nombre.Trim();
        var tipo = model.Tipo!.Value;

        if (tipo != item.Tipo && await EnUsoAsync(id))
        {
            ModelState.AddModelError(nameof(model.Tipo), CambioTipoMessage);
        }
        else if (await db.ItemsClinicos.AnyAsync(i => i.Tipo == tipo && i.Nombre == nombre && i.Id != id))
        {
            ModelState.AddModelError(nameof(model.Nombre), DuplicadoMessage);
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        item.Nombre = nombre;
        item.Tipo = tipo;
        item.Descripcion = string.IsNullOrWhiteSpace(model.Descripcion) ? null : model.Descripcion.Trim();
        item.Activo = model.Activo;
        await db.SaveChangesAsync();
        TempData["Exito"] = "Ítem actualizado.";
        return RedirectToAction(nameof(Index));
    }

    // Activar o desactivar: la forma de "retirar" un ítem en uso sin borrarlo.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CambiarActivo(int id)
    {
        var item = await db.ItemsClinicos.FindAsync(id);
        if (item is null)
        {
            return NotFound();
        }

        item.Activo = !item.Activo;
        await db.SaveChangesAsync();
        TempData["Exito"] = item.Activo ? "Ítem activado." : "Ítem desactivado.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id)
    {
        var item = await db.ItemsClinicos.FindAsync(id);
        if (item is null)
        {
            return NotFound();
        }

        ViewBag.EnUso = await EnUsoAsync(id);
        return View(item);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var item = await db.ItemsClinicos.FindAsync(id);
        if (item is null)
        {
            return NotFound();
        }

        // Regla de integridad: no se borra un ítem en uso.
        if (await EnUsoAsync(id))
        {
            TempData["Error"] = EnUsoMessage;
            return RedirectToAction(nameof(Index));
        }

        db.ItemsClinicos.Remove(item);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Ítem eliminado.";
        return RedirectToAction(nameof(Index));
    }

    private async Task<bool> EnUsoAsync(int id)
    {
        return await db.AplicacionesVacuna.AnyAsync(a => a.ItemClinicoId == id)
               || await db.AsignacionesTratamiento.AnyAsync(a => a.ItemClinicoId == id);
    }
}
