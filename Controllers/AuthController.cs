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
        if (usuario is null ||
            hasher.VerifyHashedPassword(usuario, usuario.PasswordHash, model.Password) == PasswordVerificationResult.Failed)
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

        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
        {
            return LocalRedirect(returnUrl);
        }

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
}
