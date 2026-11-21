using System.Security.Claims;
using Ganss.Xss;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;

namespace VitaVettMVC.Controllers;

/// <summary>
/// Expediente clínico de una mascota. Administradores y veterinarios lo consultan;
/// solo los veterinarios registran información, y cada registro guarda su autoría.
/// </summary>
[Authorize(Roles = "Administrador,Veterinario")]
public class ExpedienteController(AppDbContext db) : Controller
{
    private const long MaxExamenBytes = 5 * 1024 * 1024;
    private static readonly string[] TiposExamen = ["application/pdf", "image/jpeg", "image/png"];

    // Solo el formato que produce el editor de notas; todo lo demás se elimina.
    private static readonly HtmlSanitizer Sanitizador = CrearSanitizador();

    private static HtmlSanitizer CrearSanitizador()
    {
        var s = new HtmlSanitizer();
        s.AllowedTags.Clear();
        s.AllowedTags.UnionWith(["p", "br", "div", "b", "strong", "i", "em", "u", "ul", "ol", "li"]);
        s.AllowedAttributes.Clear();
        s.AllowedCssProperties.Clear();
        return s;
    }

    public async Task<IActionResult> Index(int id)
    {
        var mascota = await db.Mascotas
            .AsNoTracking()
            .Include(m => m.Especie)
            .Include(m => m.Raza)
            .Include(m => m.Dueno)
            .Include(m => m.AplicacionesVacuna).ThenInclude(a => a.ItemClinico)
            .Include(m => m.AplicacionesVacuna).ThenInclude(a => a.Veterinario).ThenInclude(v => v.Usuario)
            .Include(m => m.Tratamientos).ThenInclude(t => t.ItemClinico)
            .Include(m => m.Tratamientos).ThenInclude(t => t.Veterinario).ThenInclude(v => v.Usuario)
            .Include(m => m.Tratamientos).ThenInclude(t => t.VeterinarioSuspension!).ThenInclude(v => v.Usuario)
            .Include(m => m.Notas).ThenInclude(n => n.Veterinario).ThenInclude(v => v.Usuario)
            .AsSplitQuery()
            .FirstOrDefaultAsync(m => m.Id == id);

        if (mascota is null)
        {
            return NotFound();
        }

        // Los exámenes se listan sin su contenido binario (se descarga aparte).
        ViewBag.Examenes = await db.Examenes.AsNoTracking()
            .Where(e => e.MascotaId == id)
            .OrderByDescending(e => e.FechaSubida)
            .Select(e => new ExamenArchivo
            {
                Id = e.Id,
                Descripcion = e.Descripcion,
                NombreArchivo = e.NombreArchivo,
                ContentType = e.ContentType,
                FechaSubida = e.FechaSubida,
                Veterinario = new Veterinario { Usuario = e.Veterinario.Usuario }
            })
            .ToListAsync();

        // Solo ítems activos del catálogo se pueden asignar.
        var items = await db.ItemsClinicos.AsNoTracking()
            .Where(i => i.Activo)
            .OrderBy(i => i.Nombre)
            .ToListAsync();
        ViewBag.Vacunas = items.Where(i => i.Tipo == TipoItemClinico.Vacuna).ToList();
        ViewBag.Tratamientos = items.Where(i => i.Tipo != TipoItemClinico.Vacuna).ToList();
        ViewBag.PuedeRegistrar = await VeterinarioActualIdAsync() is not null;
        return View(mascota);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Roles = "Veterinario")]
    public async Task<IActionResult> AplicarVacuna(int id, int itemClinicoId, DateOnly? fechaAplicacion, DateOnly? proximaDosis)
    {
        var veterinarioId = await VeterinarioActualIdAsync();
        if (veterinarioId is null || !await db.Mascotas.AnyAsync(m => m.Id == id))
        {
            return NotFound();
        }

        var hoy = DateOnly.FromDateTime(DateTime.Today);
        var error =
            !await db.ItemsClinicos.AnyAsync(i => i.Id == itemClinicoId && i.Activo && i.Tipo == TipoItemClinico.Vacuna)
                ? "Seleccione una vacuna activa del catálogo."
            : fechaAplicacion is null ? "La fecha de aplicación es obligatoria."
            : fechaAplicacion > hoy ? "La fecha de aplicación no puede ser futura."
            : proximaDosis <= fechaAplicacion ? "La próxima dosis debe ser posterior a la aplicación."
            : null;

        if (error is not null)
        {
            TempData["Error"] = error;
            return RedirectToAction(nameof(Index), new { id });
        }

        db.AplicacionesVacuna.Add(new AplicacionVacuna
        {
            MascotaId = id,
            ItemClinicoId = itemClinicoId,
            VeterinarioId = veterinarioId.Value,
            FechaAplicacion = fechaAplicacion!.Value,
            ProximaDosis = proximaDosis
        });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Vacuna registrada.";
        return RedirectToAction(nameof(Index), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Roles = "Veterinario")]
    public async Task<IActionResult> AsignarTratamiento(int id, int itemClinicoId, DateOnly? fechaInicio, string? indicaciones)
    {
        var veterinarioId = await VeterinarioActualIdAsync();
        if (veterinarioId is null || !await db.Mascotas.AnyAsync(m => m.Id == id))
        {
            return NotFound();
        }

        indicaciones = string.IsNullOrWhiteSpace(indicaciones) ? null : indicaciones.Trim();
        var error =
            !await db.ItemsClinicos.AnyAsync(i => i.Id == itemClinicoId && i.Activo && i.Tipo != TipoItemClinico.Vacuna)
                ? "Seleccione un medicamento o tratamiento activo del catálogo."
            : fechaInicio is null ? "La fecha de inicio es obligatoria."
            : indicaciones?.Length > 500 ? "Las indicaciones no pueden superar 500 caracteres."
            : null;

        if (error is not null)
        {
            TempData["Error"] = error;
            return RedirectToAction(nameof(Index), new { id });
        }

        db.AsignacionesTratamiento.Add(new AsignacionTratamiento
        {
            MascotaId = id,
            ItemClinicoId = itemClinicoId,
            VeterinarioId = veterinarioId.Value,
            FechaInicio = fechaInicio!.Value,
            Indicaciones = indicaciones
        });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Tratamiento asignado.";
        return RedirectToAction(nameof(Index), new { id });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Roles = "Veterinario")]
    public async Task<IActionResult> SuspenderTratamiento(int asignacionId)
    {
        var veterinarioId = await VeterinarioActualIdAsync();
        var asignacion = await db.AsignacionesTratamiento.FindAsync(asignacionId);
        if (veterinarioId is null || asignacion is null)
        {
            return NotFound();
        }

        if (!asignacion.Suspendido)
        {
            asignacion.Suspendido = true;
            asignacion.FechaSuspension = DateOnly.FromDateTime(DateTime.Today);
            asignacion.VeterinarioSuspensionId = veterinarioId;
            await db.SaveChangesAsync();
            TempData["Exito"] = "Tratamiento suspendido.";
        }

        return RedirectToAction(nameof(Index), new { id = asignacion.MascotaId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Roles = "Veterinario")]
    [RequestSizeLimit(MaxExamenBytes + 1024 * 1024)]
    public async Task<IActionResult> SubirExamen(int id, string? descripcion, IFormFile? archivo)
    {
        var veterinarioId = await VeterinarioActualIdAsync();
        if (veterinarioId is null || !await db.Mascotas.AnyAsync(m => m.Id == id))
        {
            return NotFound();
        }

        descripcion = descripcion?.Trim();
        var error =
            string.IsNullOrEmpty(descripcion) ? "La descripción del examen es obligatoria."
            : descripcion.Length > 300 ? "La descripción no puede superar 300 caracteres."
            : archivo is null || archivo.Length == 0 ? "Seleccione un archivo."
            : archivo.Length > MaxExamenBytes ? "El archivo no puede superar 5 MB."
            : !TiposExamen.Contains(archivo.ContentType) ? "El archivo debe ser PDF, JPG o PNG."
            : null;

        if (error is not null)
        {
            TempData["Error"] = error;
            return RedirectToAction(nameof(Index), new { id });
        }

        using var stream = new MemoryStream();
        await archivo!.CopyToAsync(stream);
        db.Examenes.Add(new ExamenArchivo
        {
            MascotaId = id,
            VeterinarioId = veterinarioId.Value,
            Descripcion = descripcion!,
            Contenido = stream.ToArray(),
            ContentType = archivo.ContentType,
            NombreArchivo = Path.GetFileName(archivo.FileName)
        });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Examen subido.";
        return RedirectToAction(nameof(Index), new { id });
    }

    // El archivo vive en la BD (no hay disco persistente en Render).
    [HttpGet]
    public async Task<IActionResult> Examen(int examenId)
    {
        var examen = await db.Examenes.AsNoTracking().FirstOrDefaultAsync(e => e.Id == examenId);
        if (examen is null)
        {
            return NotFound();
        }

        Response.Headers.XContentTypeOptions = "nosniff";
        return File(examen.Contenido, examen.ContentType);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Roles = "Veterinario")]
    public async Task<IActionResult> AgregarNota(int id, string? contenido)
    {
        var veterinarioId = await VeterinarioActualIdAsync();
        if (veterinarioId is null || !await db.Mascotas.AnyAsync(m => m.Id == id))
        {
            return NotFound();
        }

        // Se sanitiza el HTML del editor para que no pueda inyectar scripts.
        var limpio = Sanitizador.Sanitize(contenido ?? "").Trim();
        if (string.IsNullOrWhiteSpace(System.Text.RegularExpressions.Regex.Replace(limpio, "<[^>]*>|&nbsp;", "")))
        {
            TempData["Error"] = "La nota no puede estar vacía.";
            return RedirectToAction(nameof(Index), new { id });
        }

        // Las notas son inmutables: no existen acciones para editarlas ni borrarlas.
        db.NotasHistorial.Add(new NotaHistorial
        {
            MascotaId = id,
            VeterinarioId = veterinarioId.Value,
            Contenido = limpio
        });
        await db.SaveChangesAsync();
        TempData["Exito"] = "Nota agregada al historial.";
        return RedirectToAction(nameof(Index), new { id });
    }

    /// <summary>Perfil de veterinario del usuario actual (null si es administrador o no tiene perfil).</summary>
    private async Task<int?> VeterinarioActualIdAsync()
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var usuarioId))
        {
            return null;
        }

        return await db.Veterinarios
            .Where(v => v.UsuarioId == usuarioId)
            .Select(v => (int?)v.Id)
            .FirstOrDefaultAsync();
    }
}
