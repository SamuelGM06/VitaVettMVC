
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;

namespace VitaVettMVC.Controllers;

[ApiController]
[Route("api/movil/mascotas")]
[Authorize(
    AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme,
    Roles = "Dueno")]
public class MovilMascotasController(AppDbContext db) : ControllerBase
{
    // Devuelve las mascotas del dueño autenticado.
    [HttpGet]
    public async Task<IActionResult> MisMascotas()
    {
        var idTexto = User.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (!int.TryParse(idTexto, out var usuarioId))
        {
            return Unauthorized();
        }

        var mascotas = await db.Mascotas
            .AsNoTracking()
            .Where(m => m.DuenoId == usuarioId)
            .OrderBy(m => m.Nombre)
            .Select(m => new
            {
                id = m.Id,
                nombre = m.Nombre,
                especie = m.Especie.Nombre,
                raza = m.Raza != null
                    ? m.Raza.Nombre
                    : null,
                tieneFoto = m.Foto != null
            })
            .ToListAsync();

        return Ok(mascotas);
    }

    // Consulta las vacunas de una mascota del dueño autenticado.
    [HttpGet("{id:int}/vacunas")]
    public async Task<IActionResult> Vacunas(int id)
    {
        var idTexto = User.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (!int.TryParse(idTexto, out var usuarioId))
        {
            return Unauthorized();
        }

        // Verificar que la mascota pertenezca al dueño.
        var mascotaExiste = await db.Mascotas
            .AnyAsync(m => m.Id == id &&
                           m.DuenoId == usuarioId);

        if (!mascotaExiste)
        {
            return NotFound(new
            {
                mensaje = "Mascota no encontrada."
            });
        }

        var hoy = DateOnly.FromDateTime(DateTime.Today);

        var vacunas = await db.AplicacionesVacuna
            .AsNoTracking()
            .Where(v => v.MascotaId == id)
            .OrderByDescending(v => v.FechaAplicacion)
            .Select(v => new
            {
                id = v.Id,
                nombre = v.ItemClinico.Nombre,
                fechaAplicacion = v.FechaAplicacion,
                proximaDosis = v.ProximaDosis,
                // Solo la última dosis de cada vacuna puede estar vencida.
                vencida = v.ProximaDosis != null &&
                          v.ProximaDosis < hoy &&
                          !db.AplicacionesVacuna.Any(b =>
                              b.MascotaId == v.MascotaId &&
                              b.ItemClinicoId == v.ItemClinicoId &&
                              b.FechaAplicacion > v.FechaAplicacion),
                veterinario =
                    v.Veterinario.Usuario.Nombre + " " +
                    v.Veterinario.Usuario.Apellidos
            })
            .ToListAsync();

        return Ok(vacunas);
    }

    // Consultar los exámenes de una mascota.
    [HttpGet("{id:int}/examenes")]
    public async Task<IActionResult> Examenes(int id)
    {
        if (!int.TryParse(
            User.FindFirstValue(ClaimTypes.NameIdentifier),
            out var usuarioId))
        {
            return Unauthorized();
        }

        var pertenece = await db.Mascotas
            .AsNoTracking()
            .AnyAsync(m => m.Id == id && m.DuenoId == usuarioId);

        if (!pertenece)
        {
            return NotFound(new { mensaje = "Mascota no encontrada." });
        }

        var examenes = await db.Examenes
            .AsNoTracking()
            .Where(e => e.MascotaId == id)
            .OrderByDescending(e => e.FechaSubida)
            .Select(e => new
            {
                id = e.Id,
                descripcion = e.Descripcion,
                nombreArchivo = e.NombreArchivo,
                tipoArchivo = e.ContentType,
                fechaSubida = e.FechaSubida,
                veterinario = e.Veterinario.Usuario.Nombre + " " +
                              e.Veterinario.Usuario.Apellidos
            })
            .ToListAsync();

        return Ok(examenes);
    }

    // Descargar un examen PDF o imagen.
    [HttpGet("{id:int}/examenes/{examenId:int}/archivo")]
    public async Task<IActionResult> DescargarExamen(
        int id, int examenId)
    {
        if (!int.TryParse(
            User.FindFirstValue(ClaimTypes.NameIdentifier),
            out var usuarioId))
        {
            return Unauthorized();
        }

        var pertenece = await db.Mascotas
            .AsNoTracking()
            .AnyAsync(m => m.Id == id && m.DuenoId == usuarioId);

        if (!pertenece)
        {
            return NotFound();
        }

        var examen = await db.Examenes
            .AsNoTracking()
            .FirstOrDefaultAsync(e =>
                e.Id == examenId && e.MascotaId == id);

        if (examen is null)
        {
            return NotFound();
        }

        Response.Headers["X-Content-Type-Options"] = "nosniff";

        return File(
            examen.Contenido,
            examen.ContentType,
            Path.GetFileName(examen.NombreArchivo));
    }

    // Consultar la fotografía de una mascota.
    [HttpGet("{id:int}/foto")]
    public async Task<IActionResult> Foto(int id)
    {
        if (!int.TryParse(
            User.FindFirstValue(ClaimTypes.NameIdentifier),
            out var usuarioId))
        {
            return Unauthorized();
        }

        var mascota = await db.Mascotas
            .AsNoTracking()
            .Where(m => m.Id == id && m.DuenoId == usuarioId)
            .Select(m => new
            {
                m.Foto,
                m.FotoContentType
            })
            .FirstOrDefaultAsync();

        if (mascota?.Foto is null)
        {
            return NotFound();
        }

        Response.Headers["X-Content-Type-Options"] = "nosniff";

        return File(
            mascota.Foto,
            mascota.FotoContentType ?? "application/octet-stream");
    }

}
