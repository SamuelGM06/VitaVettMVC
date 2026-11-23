using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VitaVettMVC.Data;
using VitaVettMVC.Models;
using VitaVettMVC.Models.ViewModels;

namespace VitaVettMVC.Controllers;

public class AuthController(AppDbContext db, IPasswordHasher<Usuario> hasher) : Controller
{
    [AllowAnonymous]
    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        ViewData["ReturnUrl"] = returnUrl;
        return View(new LoginViewModel());
    }

    [AllowAnonymous]
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel model, string? returnUrl = null)
    {
        ViewData["ReturnUrl"] = returnUrl;

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var cedula = model.Cedula.Trim();
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Cedula == cedula);

        // Mismo mensaje si la cédula no existe o la contraseña es incorrecta (no revela cuentas existentes).
        if (usuario is null || !ContrasenaValida(usuario, model.Password))
        {
            ModelState.AddModelError(string.Empty, "Cédula o contraseña incorrectas.");
            return View(model);
        }

        // Se revela el bloqueo solo después de validar la contraseña.
        if (usuario.Bloqueado)
        {
            ModelState.AddModelError(string.Empty, "Esta cuenta está bloqueada. Contacte al administrador.");
            return View(model);
        }

        await SignInAsync(usuario);

        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
        {
            return LocalRedirect(returnUrl);
        }

        return RedirectToAction("Index", "Home");
    }

    // Registro público: solo crea dueños. Administradores y veterinarios crean los demás perfiles.
    [AllowAnonymous]
    [HttpGet]
    public IActionResult Register()
    {
        return View(new RegistroDuenoViewModel());
    }

    [AllowAnonymous]
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(RegistroDuenoViewModel model)
    {
        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var cedula = model.Cedula.Trim();
        var email = model.Email.Trim();

        if (await db.Usuarios.AnyAsync(u => u.Cedula == cedula))
        {
            ModelState.AddModelError(nameof(model.Cedula), "Ya existe una cuenta con esta cédula.");
        }

        if (await db.Usuarios.AnyAsync(u => u.Email == email))
        {
            ModelState.AddModelError(nameof(model.Email), "Ya existe una cuenta con este correo.");
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        var usuario = new Usuario
        {
            Cedula = cedula,
            Nombre = model.Nombre.Trim(),
            Apellidos = model.Apellidos.Trim(),
            Email = email,
            Rol = RolUsuario.Dueno,
            Bloqueado = false
        };
        usuario.PasswordHash = hasher.HashPassword(usuario, model.Password);

        db.Usuarios.Add(usuario);
        try
        {
            await db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // Si dos registros llegan a la vez, el índice único de la BD es la última barrera.
            ModelState.AddModelError(string.Empty, "No se pudo crear la cuenta: la cédula o el correo ya están en uso.");
            return View(model);
        }

        await SignInAsync(usuario);
        return RedirectToAction("Index", "Home");
    }

    [Authorize]
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToAction(nameof(Login));
    }

    [AllowAnonymous]
    public IActionResult AccessDenied()
    {
        return View();
    }

    // Un hash mal formado (por ejemplo, el de relleno de los datos de demostración) no debe causar un error 500.
    private bool ContrasenaValida(Usuario usuario, string password)
    {
        try
        {
            return hasher.VerifyHashedPassword(usuario, usuario.PasswordHash, password) != PasswordVerificationResult.Failed;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private async Task SignInAsync(Usuario usuario)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
            new(ClaimTypes.Name, $"{usuario.Nombre} {usuario.Apellidos}"),
            new(ClaimTypes.Role, usuario.Rol.ToString())
        };
        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity));
    }
}
