using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Models;

namespace VitaVettMVC.Data;

public static class DbSeeder
{
    /// <summary>
    /// Crea el primer administrador si aún no existe ninguno.
    /// Los datos vienen de configuración (User Secrets en local, variables de entorno en Render):
    /// Admin:Cedula, Admin:Email, Admin:Nombre, Admin:Apellidos y Admin:Password.
    /// </summary>
    public static async Task SeedAdministradorAsync(
        AppDbContext db,
        IPasswordHasher<Usuario> hasher,
        IConfiguration config,
        ILogger logger)
    {
        if (await db.Usuarios.AnyAsync(u => u.Rol == RolUsuario.Administrador))
        {
            return;
        }

        var cedula = config["Admin:Cedula"];
        var email = config["Admin:Email"];
        var password = config["Admin:Password"];

        if (string.IsNullOrWhiteSpace(cedula) || string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            logger.LogWarning("No existe ningún administrador y faltan Admin:Cedula, Admin:Email o Admin:Password. No se creó ninguno.");
            return;
        }

        var admin = new Usuario
        {
            Cedula = cedula,
            Email = email,
            Nombre = config["Admin:Nombre"] ?? "Administrador",
            Apellidos = config["Admin:Apellidos"] ?? "Sistema",
            Rol = RolUsuario.Administrador,
            Bloqueado = false
        };
        admin.PasswordHash = hasher.HashPassword(admin, password);

        db.Usuarios.Add(admin);
        await db.SaveChangesAsync();
        logger.LogInformation("Administrador inicial creado con la cédula configurada.");
    }
}
