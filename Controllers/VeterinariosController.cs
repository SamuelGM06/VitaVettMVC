using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

[Authorize(Roles = "Administrador")]
public class VeterinariosController(AppDbContext db, IPasswordHasher<Usuario> hasher) : Controller
{
    private const long MaxFotoBytes = 2 * 1024 * 1024;
    private static readonly string[] TiposFoto = ["image/jpeg", "image/png"];

    public async Task<IActionResult> Index()
    {
        var veterinarios = await db.Veterinarios
            .Include(v => v.Usuario)
            .OrderBy(v => v.Usuario.Nombre)
            .ThenBy(v => v.Usuario.Apellidos)
            .ToListAsync();
        return View(veterinarios);
    }

    [HttpGet]
    public IActionResult Create()
    {
        return View(new VeterinarioFormViewModel());
    }

    // Crea el Usuario (rol Veterinario) y su perfil en una sola operación: siempre quedan vinculados.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(VeterinarioFormViewModel model)
    {
        if (string.IsNullOrWhiteSpace(model.Password))
        {
            ModelState.AddModelError(nameof(model.Password), "La contraseña es obligatoria.");
        }

        var errorFoto = ValidarFoto(model.Foto);
        if (errorFoto is not null)
        {
            ModelState.AddModelError(nameof(model.Foto), errorFoto);
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        await ValidarUnicosAsync(model, usuarioId: null, veterinarioId: null);
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var usuario = new Usuario
        {
            Cedula = model.Cedula.Trim(),
            Nombre = model.Nombre.Trim(),
            Apellidos = model.Apellidos.Trim(),
            Email = model.Email.Trim(),
            Rol = RolUsuario.Veterinario,
            Bloqueado = false
        };
        usuario.PasswordHash = hasher.HashPassword(usuario, model.Password!);

        var veterinario = new Veterinario
        {
            Usuario = usuario,
            NumeroColegiado = model.NumeroColegiado.Trim()
        };
        await AsignarFotoAsync(veterinario, model.Foto);

        db.Veterinarios.Add(veterinario);
        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(string.Empty, "No se pudo guardar: la cédula, el correo o el colegiado ya están en uso.");
            return View(model);
        }

        TempData["Exito"] = "Veterinario creado.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var veterinario = await db.Veterinarios.Include(v => v.Usuario).FirstOrDefaultAsync(v => v.Id == id);
        if (veterinario is null)
        {
            return NotFound();
        }

        ViewBag.TieneFoto = veterinario.Foto is not null;
        return View(new VeterinarioFormViewModel
        {
            Id = veterinario.Id,
            Cedula = veterinario.Usuario.Cedula,
            Nombre = veterinario.Usuario.Nombre,
            Apellidos = veterinario.Usuario.Apellidos,
            Email = veterinario.Usuario.Email,
            NumeroColegiado = veterinario.NumeroColegiado
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, VeterinarioFormViewModel model)
    {
        var veterinario = await db.Veterinarios.Include(v => v.Usuario).FirstOrDefaultAsync(v => v.Id == id);
        if (veterinario is null)
        {
            return NotFound();
        }

        model.Id = id;
        ViewBag.TieneFoto = veterinario.Foto is not null;

        var errorFoto = ValidarFoto(model.Foto);
        if (errorFoto is not null)
        {
            ModelState.AddModelError(nameof(model.Foto), errorFoto);
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        await ValidarUnicosAsync(model, usuarioId: veterinario.UsuarioId, veterinarioId: id);
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        veterinario.Usuario.Cedula = model.Cedula.Trim();
        veterinario.Usuario.Nombre = model.Nombre.Trim();
        veterinario.Usuario.Apellidos = model.Apellidos.Trim();
        veterinario.Usuario.Email = model.Email.Trim();
        veterinario.NumeroColegiado = model.NumeroColegiado.Trim();
        await AsignarFotoAsync(veterinario, model.Foto);

        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(string.Empty, "No se pudo guardar: la cédula, el correo o el colegiado ya están en uso.");
            return View(model);
        }

        TempData["Exito"] = "Veterinario actualizado.";
        return RedirectToAction(nameof(Index));
    }

    // Foto del veterinario desde la BD (no hay disco persistente en Render).
    [HttpGet]
    public async Task<IActionResult> Foto(int id)
    {
        var foto = await db.Veterinarios
            .AsNoTracking()
            .Where(v => v.Id == id)
            .Select(v => new { v.Foto, v.FotoContentType })
            .FirstOrDefaultAsync();

        if (foto?.Foto is null)
        {
            return NotFound();
        }

        return File(foto.Foto, foto.FotoContentType ?? "application/octet-stream");
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CambiarBloqueo(int id)
    {
        var veterinario = await db.Veterinarios.Include(v => v.Usuario).FirstOrDefaultAsync(v => v.Id == id);
        if (veterinario is null)
        {
            return NotFound();
        }

        if (veterinario.UsuarioId == UsuarioActualId)
        {
            TempData["Error"] = "No puede bloquear su propia cuenta.";
            return RedirectToAction(nameof(Index));
        }

        veterinario.Usuario.Bloqueado = !veterinario.Usuario.Bloqueado;
        await db.SaveChangesAsync();
        TempData["Exito"] = veterinario.Usuario.Bloqueado ? "Cuenta bloqueada." : "Cuenta desbloqueada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id)
    {
        var veterinario = await db.Veterinarios.Include(v => v.Usuario).FirstOrDefaultAsync(v => v.Id == id);
        if (veterinario is null)
        {
            return NotFound();
        }

        ViewBag.EnUso = await EnUsoAsync(veterinario);
        return View(veterinario);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var veterinario = await db.Veterinarios.Include(v => v.Usuario).FirstOrDefaultAsync(v => v.Id == id);
        if (veterinario is null)
        {
            return NotFound();
        }

        if (veterinario.UsuarioId == UsuarioActualId)
        {
            TempData["Error"] = "No puede eliminar su propia cuenta.";
            return RedirectToAction(nameof(Index));
        }

        // Regla de integridad: no se elimina un veterinario con registros clínicos o mascotas a su nombre.
        if (await EnUsoAsync(veterinario))
        {
            TempData["Error"] = "No se puede eliminar: tiene registros clínicos o mascotas asociados. Puede bloquear la cuenta.";
            return RedirectToAction(nameof(Index));
        }

        db.Veterinarios.Remove(veterinario);
        db.Usuarios.Remove(veterinario.Usuario);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Veterinario eliminado.";
        return RedirectToAction(nameof(Index));
    }

    private int UsuarioActualId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : -1;

    private async Task<bool> EnUsoAsync(Veterinario veterinario)
    {
        var id = veterinario.Id;
        return await db.AplicacionesVacuna.AnyAsync(a => a.VeterinarioId == id)
               || await db.AsignacionesTratamiento.AnyAsync(a => a.VeterinarioId == id || a.VeterinarioSuspensionId == id)
               || await db.Examenes.AnyAsync(e => e.VeterinarioId == id)
               || await db.NotasHistorial.AnyAsync(n => n.VeterinarioId == id)
               || await db.Mascotas.AnyAsync(m => m.DuenoId == veterinario.UsuarioId);
    }

    private async Task ValidarUnicosAsync(VeterinarioFormViewModel model, int? usuarioId, int? veterinarioId)
    {
        var cedula = model.Cedula.Trim();
        var email = model.Email.Trim();
        var colegiado = model.NumeroColegiado.Trim();

        if (await db.Usuarios.AnyAsync(u => u.Cedula == cedula && u.Id != usuarioId))
        {
            ModelState.AddModelError(nameof(model.Cedula), "Ya existe una cuenta con esta cédula.");
        }

        if (await db.Usuarios.AnyAsync(u => u.Email == email && u.Id != usuarioId))
        {
            ModelState.AddModelError(nameof(model.Email), "Ya existe una cuenta con este correo.");
        }

        if (await db.Veterinarios.AnyAsync(v => v.NumeroColegiado == colegiado && v.Id != veterinarioId))
        {
            ModelState.AddModelError(nameof(model.NumeroColegiado), "Ya existe un veterinario con este número de colegiado.");
        }
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

    private static async Task AsignarFotoAsync(Veterinario veterinario, IFormFile? foto)
    {
        if (foto is null || foto.Length == 0)
        {
            return;
        }

        using var stream = new MemoryStream();
        await foto.CopyToAsync(stream);
        veterinario.Foto = stream.ToArray();
        veterinario.FotoContentType = foto.ContentType;
    }
}
