
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using VitaVettMVC.Data;
using VitaVettMVC.Models;

namespace VitaVettMVC.Controllers;

public class LoginMovilRequest
{
    public string Cedula { get; set; } = "";
    public string Password { get; set; } = "";
}

[ApiController]
[Route("api/movil/auth")]
public class MovilAuthController(
    AppDbContext db,
    IPasswordHasher<Usuario> hasher,
    IConfiguration configuration) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login(
        [FromBody] LoginMovilRequest model)
    {
        if (string.IsNullOrWhiteSpace(model.Cedula) ||
            string.IsNullOrWhiteSpace(model.Password))
        {
            return BadRequest(new
            {
                mensaje = "La cédula y la contraseña son obligatorias."
            });
        }

        var usuario = await db.Usuarios
            .FirstOrDefaultAsync(u =>
                u.Cedula == model.Cedula.Trim());

        if (usuario is null ||
            hasher.VerifyHashedPassword(
                usuario,
                usuario.PasswordHash,
                model.Password) == PasswordVerificationResult.Failed)
        {
            return Unauthorized(new
            {
                mensaje = "Credenciales incorrectas."
            });
        }

        if (usuario.Bloqueado)
        {
            return Unauthorized(new
            {
                mensaje = "Esta cuenta está bloqueada."
            });
        }

        if (usuario.Rol != RolUsuario.Dueno)
        {
            return StatusCode(403, new
            {
                mensaje = "Acceso exclusivo para dueños."
            });
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
            new(ClaimTypes.Name, usuario.Nombre),
            new(ClaimTypes.Role, usuario.Rol.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var key = configuration["Jwt:Key"]!;

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(key)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: "VitaVettMVC",
            audience: "VitaVettMovil",
            claims: claims,
            expires: DateTime.UtcNow.AddHours(8),
            signingCredentials: credentials);

        return Ok(new
        {
            token = new JwtSecurityTokenHandler().WriteToken(token),
            expiraEnUtc = token.ValidTo,
            nombre = $"{usuario.Nombre} {usuario.Apellidos}"
        });
    }
}
