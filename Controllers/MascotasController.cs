using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

/// <summary>Pacientes (mascotas). Los gestionan administradores y veterinarios.</summary>
[Authorize(Roles = "Administrador,Veterinario")]
public class MascotasController(AppDbContext db) : Controller
{
    private const long MaxFotoBytes = 2 * 1024 * 1024;
    private static readonly string[] TiposFoto = ["image/jpeg", "image/png"];

    public async Task<IActionResult> Index(string? buscar)
    {
        var query = db.Mascotas
            .Include(m => m.Especie)
            .Include(m => m.Raza)
            .Include(m => m.Dueno)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(buscar))
        {
            var texto = buscar.Trim();
            query = query.Where(m => m.Nombre.Contains(texto)
                                     || m.Dueno.Nombre.Contains(texto)
                                     || m.Dueno.Apellidos.Contains(texto)
                                     || m.Dueno.Cedula.Contains(texto));
        }

        ViewBag.Buscar = buscar;
        return View(await query.OrderBy(m => m.Nombre).ToListAsync());
    }

    [HttpGet]
    public async Task<IActionResult> Create()
    {
        return View(await CargarListasAsync(new MascotaFormViewModel()));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(MascotaFormViewModel model)
    {
        await ValidarAsync(model);
        if (!ModelState.IsValid)
        {
            return View(await CargarListasAsync(model));
        }

        var mascota = new Mascota();
        await AsignarAsync(mascota, model);
        db.Mascotas.Add(mascota);
        await db.SaveChangesAsync();

        TempData["Exito"] = "Mascota registrada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var mascota = await db.Mascotas.FindAsync(id);
        if (mascota is null)
        {
            return NotFound();
        }

        ViewBag.TieneFoto = mascota.Foto is not null;
        return View(await CargarListasAsync(new MascotaFormViewModel
        {
            Id = mascota.Id,
            Nombre = mascota.Nombre,
            EspecieId = mascota.EspecieId,
            RazaId = mascota.RazaId,
            DuenoId = mascota.DuenoId,
            FechaNacimiento = mascota.FechaNacimiento,
            Sexo = mascota.Sexo
        }));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, MascotaFormViewModel model)
    {
        var mascota = await db.Mascotas.FindAsync(id);
        if (mascota is null)
        {
            return NotFound();
        }

        model.Id = id;
        ViewBag.TieneFoto = mascota.Foto is not null;

        await ValidarAsync(model);
        if (!ModelState.IsValid)
        {
            return View(await CargarListasAsync(model));
        }

        await AsignarAsync(mascota, model);
        await db.SaveChangesAsync();

        TempData["Exito"] = "Mascota actualizada.";
        return RedirectToAction(nameof(Index));
    }

    // Foto desde la BD (no hay disco persistente en Render).
    [HttpGet]
    public async Task<IActionResult> Foto(int id)
    {
        var foto = await db.Mascotas
            .AsNoTracking()
            .Where(m => m.Id == id)
            .Select(m => new { m.Foto, m.FotoContentType })
            .FirstOrDefaultAsync();

        if (foto?.Foto is null)
        {
            return NotFound();
        }

        return File(foto.Foto, foto.FotoContentType ?? "application/octet-stream");
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id)
    {
        var mascota = await db.Mascotas
            .Include(m => m.Especie)
            .Include(m => m.Dueno)
            .FirstOrDefaultAsync(m => m.Id == id);
        if (mascota is null)
        {
            return NotFound();
        }

        ViewBag.EnUso = await TieneExpedienteAsync(id);
        return View(mascota);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var mascota = await db.Mascotas.FindAsync(id);
        if (mascota is null)
        {
            return NotFound();
        }

        // Regla de integridad: una mascota con expediente no se borra.
        if (await TieneExpedienteAsync(id))
        {
            TempData["Error"] = "No se puede eliminar: la mascota ya tiene registros en su expediente.";
            return RedirectToAction(nameof(Index));
        }

        db.Mascotas.Remove(mascota);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Mascota eliminada.";
        return RedirectToAction(nameof(Index));
    }

    private async Task<bool> TieneExpedienteAsync(int id)
    {
        return await db.AplicacionesVacuna.AnyAsync(a => a.MascotaId == id)
               || await db.AsignacionesTratamiento.AnyAsync(a => a.MascotaId == id)
               || await db.Examenes.AnyAsync(e => e.MascotaId == id)
               || await db.NotasHistorial.AnyAsync(n => n.MascotaId == id);
    }

    private async Task ValidarAsync(MascotaFormViewModel model)
    {
        var errorFoto = ValidarFoto(model.Foto);
        if (errorFoto is not null)
        {
            ModelState.AddModelError(nameof(model.Foto), errorFoto);
        }

        if (model.EspecieId is { } especieId && !await db.Especies.AnyAsync(e => e.Id == especieId))
        {
            ModelState.AddModelError(nameof(model.EspecieId), "La especie seleccionada no existe.");
        }

        // La raza es opcional, pero si se elige debe pertenecer a la especie.
        if (model.RazaId is { } razaId && !await db.Razas.AnyAsync(r => r.Id == razaId && r.EspecieId == model.EspecieId))
        {
            ModelState.AddModelError(nameof(model.RazaId), "La raza no pertenece a la especie seleccionada.");
        }

        if (model.DuenoId is { } duenoId && !await db.Usuarios.AnyAsync(u => u.Id == duenoId && u.Rol == RolUsuario.Dueno))
        {
            ModelState.AddModelError(nameof(model.DuenoId), "El dueño seleccionado no existe.");
        }

        if (model.FechaNacimiento > DateOnly.FromDateTime(DateTime.Today))
        {
            ModelState.AddModelError(nameof(model.FechaNacimiento), "La fecha de nacimiento no puede ser futura.");
        }
    }

    private static async Task AsignarAsync(Mascota mascota, MascotaFormViewModel model)
    {
        mascota.Nombre = model.Nombre.Trim();
        mascota.EspecieId = model.EspecieId!.Value;
        mascota.RazaId = model.RazaId;
        mascota.DuenoId = model.DuenoId!.Value;
        mascota.FechaNacimiento = model.FechaNacimiento;
        mascota.Sexo = string.IsNullOrWhiteSpace(model.Sexo) ? null : model.Sexo.Trim();

        if (model.Foto is { Length: > 0 } foto)
        {
            using var stream = new MemoryStream();
            await foto.CopyToAsync(stream);
            mascota.Foto = stream.ToArray();
            mascota.FotoContentType = foto.ContentType;
        }
    }

    private async Task<MascotaFormViewModel> CargarListasAsync(MascotaFormViewModel model)
    {
        model.Especies = await db.Especies.OrderBy(e => e.Nombre).ToListAsync();
        model.Razas = await db.Razas.OrderBy(r => r.Nombre).ToListAsync();
        model.Duenos = await db.Usuarios
            .Where(u => u.Rol == RolUsuario.Dueno && (!u.Bloqueado || u.Id == model.DuenoId))
            .OrderBy(u => u.Nombre).ThenBy(u => u.Apellidos)
            .ToListAsync();
        return model;
    }

    private static string? ValidarFoto(IFormFile? foto)
    {
        if (foto is null || foto.Length == 0)
        {
            return null;
        }

        if (foto.Length > MaxFotoBytes)
        {
            return "La foto no puede superar 2 MB.";
        }

        return TiposFoto.Contains(foto.ContentType) ? null : "La foto debe ser JPG o PNG.";
    }
}
