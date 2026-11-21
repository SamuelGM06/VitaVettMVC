using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

/// <summary>
/// Gestión de administradores y dueños. Los veterinarios se gestionan en VeterinariosController
/// porque cada uno requiere su perfil vinculado.
/// </summary>
[Authorize(Roles = "Administrador")]
public class UsuariosController(AppDbContext db, IPasswordHasher<Usuario> hasher) : Controller
{
    private static readonly RolUsuario[] RolesGestionables = [RolUsuario.Administrador, RolUsuario.Dueno];

    private int UsuarioActualId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : -1;

    public async Task<IActionResult> Index(RolUsuario? rol)
    {
        var query = db.Usuarios.AsQueryable();
        if (rol.HasValue)
        {
            query = query.Where(u => u.Rol == rol.Value);
        }

        var usuarios = await query
            .OrderBy(u => u.Rol)
            .ThenBy(u => u.Nombre)
            .ThenBy(u => u.Apellidos)
            .ToListAsync();

        ViewBag.RolSeleccionado = rol;
        return View(usuarios);
    }

    [HttpGet]
    public IActionResult Create()
    {
        var model = new UsuarioFormViewModel { Rol = RolUsuario.Dueno };
        PrepararFormulario(model);
        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(UsuarioFormViewModel model)
    {
        if (string.IsNullOrWhiteSpace(model.Password))
        {
            ModelState.AddModelError(nameof(model.Password), "La contraseña es obligatoria.");
        }

        if (model.Rol is not null && !RolesGestionables.Contains(model.Rol.Value))
        {
            ModelState.AddModelError(nameof(model.Rol), "Los veterinarios se crean desde el módulo de Veterinarios.");
        }

        if (!ModelState.IsValid)
        {
            PrepararFormulario(model);
            return View(model);
        }

        await ValidarUnicosAsync(model, excluirId: null);
        if (!ModelState.IsValid)
        {
            PrepararFormulario(model);
            return View(model);
        }

        var usuario = new Usuario
        {
            Cedula = model.Cedula.Trim(),
            Nombre = model.Nombre.Trim(),
            Apellidos = model.Apellidos.Trim(),
            Email = model.Email.Trim(),
            Rol = model.Rol!.Value,
            Bloqueado = false
        };
        usuario.PasswordHash = hasher.HashPassword(usuario, model.Password!);

        db.Usuarios.Add(usuario);
        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(string.Empty, "No se pudo guardar: la cédula o el correo ya están en uso.");
            PrepararFormulario(model);
            return View(model);
        }

        TempData["Exito"] = "Usuario creado.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        if (usuario.Rol == RolUsuario.Veterinario)
        {
            return await RedirigirAVeterinarioAsync(id);
        }

        var model = new UsuarioFormViewModel
        {
            Id = usuario.Id,
            Cedula = usuario.Cedula,
            Nombre = usuario.Nombre,
            Apellidos = usuario.Apellidos,
            Email = usuario.Email,
            Rol = usuario.Rol
        };
        PrepararFormulario(model);
        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, UsuarioFormViewModel model)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        if (usuario.Rol == RolUsuario.Veterinario)
        {
            return await RedirigirAVeterinarioAsync(id);
        }

        model.Id = id;

        if (model.Rol is not null && !RolesGestionables.Contains(model.Rol.Value))
        {
            ModelState.AddModelError(nameof(model.Rol), "Los veterinarios se gestionan desde el módulo de Veterinarios.");
        }

        if (!ModelState.IsValid)
        {
            PrepararFormulario(model);
            return View(model);
        }

        var nuevoRol = model.Rol!.Value;
        if (nuevoRol != usuario.Rol)
        {
            if (id == UsuarioActualId)
            {
                ModelState.AddModelError(nameof(model.Rol), "No puede cambiar su propio rol.");
            }
            else if (usuario.Rol == RolUsuario.Administrador && await EsUltimoAdminActivoAsync(usuario))
            {
                ModelState.AddModelError(nameof(model.Rol), "Debe quedar al menos un administrador activo.");
            }
        }

        await ValidarUnicosAsync(model, excluirId: id);
        if (!ModelState.IsValid)
        {
            PrepararFormulario(model);
            return View(model);
        }

        usuario.Cedula = model.Cedula.Trim();
        usuario.Nombre = model.Nombre.Trim();
        usuario.Apellidos = model.Apellidos.Trim();
        usuario.Email = model.Email.Trim();
        usuario.Rol = nuevoRol;

        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            ModelState.AddModelError(string.Empty, "No se pudo guardar: la cédula o el correo ya están en uso.");
            PrepararFormulario(model);
            return View(model);
        }

        TempData["Exito"] = "Usuario actualizado.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CambiarBloqueo(int id)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        if (usuario.Rol == RolUsuario.Veterinario)
        {
            return await RedirigirAVeterinarioAsync(id);
        }

        if (id == UsuarioActualId)
        {
            TempData["Error"] = "No puede bloquear su propia cuenta.";
            return RedirectToAction(nameof(Index));
        }

        if (!usuario.Bloqueado && usuario.Rol == RolUsuario.Administrador && await EsUltimoAdminActivoAsync(usuario))
        {
            TempData["Error"] = "Debe quedar al menos un administrador activo.";
            return RedirectToAction(nameof(Index));
        }

        usuario.Bloqueado = !usuario.Bloqueado;
        await db.SaveChangesAsync();
        TempData["Exito"] = usuario.Bloqueado ? "Cuenta bloqueada." : "Cuenta desbloqueada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> CambiarPassword(int id)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        if (usuario.Rol == RolUsuario.Veterinario)
        {
            return await RedirigirAVeterinarioAsync(id);
        }

        return View(new ResetPasswordViewModel
        {
            Id = usuario.Id,
            NombreCompleto = $"{usuario.Nombre} {usuario.Apellidos}"
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CambiarPassword(int id, ResetPasswordViewModel model)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        model.Id = id;
        model.NombreCompleto = $"{usuario.Nombre} {usuario.Apellidos}";

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        usuario.PasswordHash = hasher.HashPassword(usuario, model.Password);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Contraseña actualizada.";
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        if (usuario.Rol == RolUsuario.Veterinario)
        {
            return await RedirigirAVeterinarioAsync(id);
        }

        ViewBag.Motivo = await MotivoNoEliminarAsync(usuario);
        return View(usuario);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var usuario = await db.Usuarios.FindAsync(id);
        if (usuario is null)
        {
            return NotFound();
        }

        if (usuario.Rol == RolUsuario.Veterinario)
        {
            return await RedirigirAVeterinarioAsync(id);
        }

        var motivo = await MotivoNoEliminarAsync(usuario);
        if (motivo is not null)
        {
            TempData["Error"] = motivo;
            return RedirectToAction(nameof(Index));
        }

        db.Usuarios.Remove(usuario);
        await db.SaveChangesAsync();
        TempData["Exito"] = "Usuario eliminado.";
        return RedirectToAction(nameof(Index));
    }

    private async Task<string?> MotivoNoEliminarAsync(Usuario usuario)
    {
        if (usuario.Id == UsuarioActualId)
        {
            return "No puede eliminar su propia cuenta.";
        }

        if (await db.Mascotas.AnyAsync(m => m.DuenoId == usuario.Id))
        {
            return "No se puede eliminar: el dueño tiene mascotas registradas. Puede bloquear la cuenta.";
        }

        if (usuario.Rol == RolUsuario.Administrador && await EsUltimoAdminActivoAsync(usuario))
        {
            return "Debe quedar al menos un administrador activo.";
        }

        return null;
    }

    // Verdadero si el usuario es el único administrador activo (ignora al propio usuario en el conteo).
    private async Task<bool> EsUltimoAdminActivoAsync(Usuario usuario)
    {
        var otrosAdminsActivos = await db.Usuarios.CountAsync(u =>
            u.Rol == RolUsuario.Administrador && !u.Bloqueado && u.Id != usuario.Id);
        return otrosAdminsActivos == 0;
    }

    private async Task ValidarUnicosAsync(UsuarioFormViewModel model, int? excluirId)
    {
        var cedula = model.Cedula.Trim();
        var email = model.Email.Trim();

        if (await db.Usuarios.AnyAsync(u => u.Cedula == cedula && u.Id != excluirId))
        {
            ModelState.AddModelError(nameof(model.Cedula), "Ya existe una cuenta con esta cédula.");
        }

        if (await db.Usuarios.AnyAsync(u => u.Email == email && u.Id != excluirId))
        {
            ModelState.AddModelError(nameof(model.Email), "Ya existe una cuenta con este correo.");
        }
    }

    private void PrepararFormulario(UsuarioFormViewModel model)
    {
        ViewBag.Roles = new SelectList(
            RolesGestionables.Select(r => new { Valor = r, Texto = r.ToString() }),
            "Valor",
            "Texto",
            model.Rol);
    }

    private async Task<IActionResult> RedirigirAVeterinarioAsync(int usuarioId)
    {
        var veterinarioId = await db.Veterinarios
            .Where(v => v.UsuarioId == usuarioId)
            .Select(v => (int?)v.Id)
            .FirstOrDefaultAsync();

        if (veterinarioId is null)
        {
            return NotFound();
        }

        return RedirectToAction("Edit", "Veterinarios", new { id = veterinarioId.Value });
    }
}
