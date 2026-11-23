-- =====================================================================
-- Datos de prueba / demostración para VitaVettMVC
--
-- - Es re-ejecutable: cada inserción verifica antes si ya existe.
-- - NO crea administradores: el administrador inicial lo crea la app
--   al arrancar (DbSeeder) con Admin__Cedula / Admin__Password.
-- - Los veterinarios y dueños se crean con una contraseña de relleno que
--   NO sirve para iniciar sesión. Para usarlos, el administrador les
--   asigna una contraseña desde Usuarios > Contraseña.
-- - Ejecutar primero en LocalDB, nunca directamente en somee sin revisar:
--     sqlcmd -E -S "(localdb)\MSSQLLocalDB" -d VitaVettMVC -i scripts\datos_prueba.sql
-- =====================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- ---------------------------------------------------------------------
-- 1. Especies y razas
-- ---------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Especies WHERE Nombre = 'Perro') INSERT INTO Especies (Nombre) VALUES ('Perro');
IF NOT EXISTS (SELECT 1 FROM Especies WHERE Nombre = 'Gato')  INSERT INTO Especies (Nombre) VALUES ('Gato');
IF NOT EXISTS (SELECT 1 FROM Especies WHERE Nombre = 'Conejo') INSERT INTO Especies (Nombre) VALUES ('Conejo');

DECLARE @Perro INT = (SELECT Id FROM Especies WHERE Nombre = 'Perro');
DECLARE @Gato  INT = (SELECT Id FROM Especies WHERE Nombre = 'Gato');
DECLARE @Conejo INT = (SELECT Id FROM Especies WHERE Nombre = 'Conejo');

IF NOT EXISTS (SELECT 1 FROM Razas WHERE EspecieId = @Perro AND Nombre = 'Labrador')      INSERT INTO Razas (EspecieId, Nombre) VALUES (@Perro, 'Labrador');
IF NOT EXISTS (SELECT 1 FROM Razas WHERE EspecieId = @Perro AND Nombre = 'Pastor alemán') INSERT INTO Razas (EspecieId, Nombre) VALUES (@Perro, 'Pastor alemán');
IF NOT EXISTS (SELECT 1 FROM Razas WHERE EspecieId = @Perro AND Nombre = 'Criollo')       INSERT INTO Razas (EspecieId, Nombre) VALUES (@Perro, 'Criollo');
IF NOT EXISTS (SELECT 1 FROM Razas WHERE EspecieId = @Gato  AND Nombre = 'Siamés')        INSERT INTO Razas (EspecieId, Nombre) VALUES (@Gato, 'Siamés');
IF NOT EXISTS (SELECT 1 FROM Razas WHERE EspecieId = @Gato  AND Nombre = 'Común europeo') INSERT INTO Razas (EspecieId, Nombre) VALUES (@Gato, 'Común europeo');
IF NOT EXISTS (SELECT 1 FROM Razas WHERE EspecieId = @Conejo AND Nombre = 'Enano')         INSERT INTO Razas (EspecieId, Nombre) VALUES (@Conejo, 'Enano');

-- ---------------------------------------------------------------------
-- 2. Catálogo clínico (medicamentos, tratamientos y vacunas)
-- ---------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Medicamento' AND Nombre = 'Amoxicilina')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Amoxicilina', 'Medicamento', 'Antibiótico de amplio espectro', 1);
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Medicamento' AND Nombre = 'Meloxicam')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Meloxicam', 'Medicamento', 'Antiinflamatorio', 1);
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Tratamiento' AND Nombre = 'Desparasitación')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Desparasitación', 'Tratamiento', 'Control de parásitos internos y externos', 1);
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Tratamiento' AND Nombre = 'Fisioterapia')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Fisioterapia', 'Tratamiento', 'Rehabilitación física', 1);
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Vacuna' AND Nombre = 'Rabia')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Rabia', 'Vacuna', 'Vacuna antirrábica', 1);
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Vacuna' AND Nombre = 'Parvovirus')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Parvovirus', 'Vacuna', 'Vacuna canina', 1);
IF NOT EXISTS (SELECT 1 FROM ItemsClinicos WHERE Tipo = 'Vacuna' AND Nombre = 'Triple felina')
    INSERT INTO ItemsClinicos (Nombre, Tipo, Descripcion, Activo) VALUES ('Triple felina', 'Vacuna', 'Panleucopenia, rinotraqueítis y calicivirus', 1);

DECLARE @Amoxicilina INT = (SELECT Id FROM ItemsClinicos WHERE Tipo = 'Medicamento' AND Nombre = 'Amoxicilina');
DECLARE @Desparasitacion INT = (SELECT Id FROM ItemsClinicos WHERE Tipo = 'Tratamiento' AND Nombre = 'Desparasitación');
DECLARE @Rabia INT = (SELECT Id FROM ItemsClinicos WHERE Tipo = 'Vacuna' AND Nombre = 'Rabia');
DECLARE @Parvovirus INT = (SELECT Id FROM ItemsClinicos WHERE Tipo = 'Vacuna' AND Nombre = 'Parvovirus');
DECLARE @Triple INT = (SELECT Id FROM ItemsClinicos WHERE Tipo = 'Vacuna' AND Nombre = 'Triple felina');

-- ---------------------------------------------------------------------
-- 3. Usuarios: veterinarios y dueños
--    PasswordHash de relleno: no es un hash válido, así que no permite iniciar sesión.
-- ---------------------------------------------------------------------
DECLARE @HashRelleno NVARCHAR(MAX) = N'SIN-CONTRASENA-DEMO';

IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Cedula = '700000001')
    INSERT INTO Usuarios (Cedula, Nombre, Apellidos, Email, PasswordHash, Rol, Bloqueado, FechaCreacion)
    VALUES ('700000001', 'María', 'Rojas Vargas', 'maria.rojas@demo.test', @HashRelleno, 'Veterinario', 0, SYSUTCDATETIME());
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Cedula = '700000002')
    INSERT INTO Usuarios (Cedula, Nombre, Apellidos, Email, PasswordHash, Rol, Bloqueado, FechaCreacion)
    VALUES ('700000002', 'Jorge', 'Mora Salas', 'jorge.mora@demo.test', @HashRelleno, 'Veterinario', 0, SYSUTCDATETIME());
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Cedula = '800000001')
    INSERT INTO Usuarios (Cedula, Nombre, Apellidos, Email, PasswordHash, Rol, Bloqueado, FechaCreacion)
    VALUES ('800000001', 'Carlos', 'Jiménez Ruiz', 'carlos.jimenez@demo.test', @HashRelleno, 'Dueno', 0, SYSUTCDATETIME());
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Cedula = '800000002')
    INSERT INTO Usuarios (Cedula, Nombre, Apellidos, Email, PasswordHash, Rol, Bloqueado, FechaCreacion)
    VALUES ('800000002', 'Ana', 'Solís Campos', 'ana.solis@demo.test', @HashRelleno, 'Dueno', 0, SYSUTCDATETIME());
IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE Cedula = '800000003')
    INSERT INTO Usuarios (Cedula, Nombre, Apellidos, Email, PasswordHash, Rol, Bloqueado, FechaCreacion)
    VALUES ('800000003', 'Luis', 'Vega Araya', 'luis.vega@demo.test', @HashRelleno, 'Dueno', 0, SYSUTCDATETIME());

-- Perfiles de veterinario (1:1 con su usuario)
IF NOT EXISTS (SELECT 1 FROM Veterinarios WHERE NumeroColegiado = 'CVP-1001')
    INSERT INTO Veterinarios (UsuarioId, NumeroColegiado)
    SELECT Id, 'CVP-1001' FROM Usuarios WHERE Cedula = '700000001';
IF NOT EXISTS (SELECT 1 FROM Veterinarios WHERE NumeroColegiado = 'CVP-1002')
    INSERT INTO Veterinarios (UsuarioId, NumeroColegiado)
    SELECT Id, 'CVP-1002' FROM Usuarios WHERE Cedula = '700000002';

DECLARE @Vet1 INT = (SELECT v.Id FROM Veterinarios v JOIN Usuarios u ON u.Id = v.UsuarioId WHERE u.Cedula = '700000001');
DECLARE @Vet2 INT = (SELECT v.Id FROM Veterinarios v JOIN Usuarios u ON u.Id = v.UsuarioId WHERE u.Cedula = '700000002');
DECLARE @Dueno1 INT = (SELECT Id FROM Usuarios WHERE Cedula = '800000001');
DECLARE @Dueno2 INT = (SELECT Id FROM Usuarios WHERE Cedula = '800000002');
DECLARE @Dueno3 INT = (SELECT Id FROM Usuarios WHERE Cedula = '800000003');

-- ---------------------------------------------------------------------
-- 4. Mascotas
-- ---------------------------------------------------------------------
DECLARE @Labrador INT = (SELECT Id FROM Razas WHERE EspecieId = @Perro AND Nombre = 'Labrador');
DECLARE @Pastor INT = (SELECT Id FROM Razas WHERE EspecieId = @Perro AND Nombre = 'Pastor alemán');
DECLARE @Siames INT = (SELECT Id FROM Razas WHERE EspecieId = @Gato AND Nombre = 'Siamés');
DECLARE @Enano INT = (SELECT Id FROM Razas WHERE EspecieId = @Conejo AND Nombre = 'Enano');

IF NOT EXISTS (SELECT 1 FROM Mascotas WHERE Nombre = 'Firulais' AND DuenoId = @Dueno1)
    INSERT INTO Mascotas (Nombre, EspecieId, RazaId, DuenoId, FechaNacimiento, Sexo)
    VALUES ('Firulais', @Perro, @Labrador, @Dueno1, '2020-03-15', 'Macho');
IF NOT EXISTS (SELECT 1 FROM Mascotas WHERE Nombre = 'Michi' AND DuenoId = @Dueno2)
    INSERT INTO Mascotas (Nombre, EspecieId, RazaId, DuenoId, FechaNacimiento, Sexo)
    VALUES ('Michi', @Gato, @Siames, @Dueno2, '2022-07-01', 'Hembra');
IF NOT EXISTS (SELECT 1 FROM Mascotas WHERE Nombre = 'Rocky' AND DuenoId = @Dueno2)
    INSERT INTO Mascotas (Nombre, EspecieId, RazaId, DuenoId, FechaNacimiento, Sexo)
    VALUES ('Rocky', @Perro, @Pastor, @Dueno2, '2018-11-20', 'Macho');
IF NOT EXISTS (SELECT 1 FROM Mascotas WHERE Nombre = 'Copito' AND DuenoId = @Dueno3)
    INSERT INTO Mascotas (Nombre, EspecieId, RazaId, DuenoId, FechaNacimiento, Sexo)
    VALUES ('Copito', @Conejo, @Enano, @Dueno3, '2023-01-10', 'Macho');

DECLARE @Firulais INT = (SELECT Id FROM Mascotas WHERE Nombre = 'Firulais' AND DuenoId = @Dueno1);
DECLARE @Michi INT = (SELECT Id FROM Mascotas WHERE Nombre = 'Michi' AND DuenoId = @Dueno2);

-- ---------------------------------------------------------------------
-- 5. Expediente clínico
--    Fechas fijas para que las vacunas vencidas y vigentes sean predecibles.
-- ---------------------------------------------------------------------

-- Vacunas: algunas vencidas (ProximaDosis pasada) y otras vigentes
IF NOT EXISTS (SELECT 1 FROM AplicacionesVacuna WHERE MascotaId = @Firulais AND ItemClinicoId = @Rabia AND FechaAplicacion = '2025-01-10')
    INSERT INTO AplicacionesVacuna (MascotaId, ItemClinicoId, VeterinarioId, FechaAplicacion, ProximaDosis)
    VALUES (@Firulais, @Rabia, @Vet1, '2025-01-10', '2026-01-10');
IF NOT EXISTS (SELECT 1 FROM AplicacionesVacuna WHERE MascotaId = @Firulais AND ItemClinicoId = @Parvovirus AND FechaAplicacion = '2026-10-01')
    INSERT INTO AplicacionesVacuna (MascotaId, ItemClinicoId, VeterinarioId, FechaAplicacion, ProximaDosis)
    VALUES (@Firulais, @Parvovirus, @Vet1, '2026-10-01', '2027-10-01');
IF NOT EXISTS (SELECT 1 FROM AplicacionesVacuna WHERE MascotaId = @Michi AND ItemClinicoId = @Triple AND FechaAplicacion = '2026-02-01')
    INSERT INTO AplicacionesVacuna (MascotaId, ItemClinicoId, VeterinarioId, FechaAplicacion, ProximaDosis)
    VALUES (@Michi, @Triple, @Vet2, '2026-02-01', '2026-08-01');

-- Tratamientos: uno vigente y uno suspendido
IF NOT EXISTS (SELECT 1 FROM AsignacionesTratamiento WHERE MascotaId = @Firulais AND ItemClinicoId = @Desparasitacion AND FechaInicio = '2026-09-01')
    INSERT INTO AsignacionesTratamiento (MascotaId, ItemClinicoId, VeterinarioId, FechaInicio, Indicaciones, Suspendido)
    VALUES (@Firulais, @Desparasitacion, @Vet1, '2026-09-01', 'Una tableta cada 3 meses', 0);
IF NOT EXISTS (SELECT 1 FROM AsignacionesTratamiento WHERE MascotaId = @Michi AND ItemClinicoId = @Amoxicilina AND FechaInicio = '2026-05-01')
    INSERT INTO AsignacionesTratamiento (MascotaId, ItemClinicoId, VeterinarioId, FechaInicio, Indicaciones, Suspendido, FechaSuspension, VeterinarioSuspensionId)
    VALUES (@Michi, @Amoxicilina, @Vet2, '2026-05-01', '10 días, cada 12 horas', 1, '2026-05-10', @Vet2);

-- Notas de historial (inmutables): FechaRegistro se indica explícitamente
IF NOT EXISTS (SELECT 1 FROM NotasHistorial WHERE MascotaId = @Firulais AND FechaRegistro = '2026-10-01T09:00:00')
    INSERT INTO NotasHistorial (MascotaId, VeterinarioId, Contenido, FechaRegistro)
    VALUES (@Firulais, @Vet1, N'<p>Control anual. Peso estable y buen estado general.</p>', '2026-10-01T09:00:00');
IF NOT EXISTS (SELECT 1 FROM NotasHistorial WHERE MascotaId = @Michi AND FechaRegistro = '2026-05-01T10:30:00')
    INSERT INTO NotasHistorial (MascotaId, VeterinarioId, Contenido, FechaRegistro)
    VALUES (@Michi, @Vet2, N'<p>Infección leve en vías respiratorias. Se inicia antibiótico.</p>', '2026-05-01T10:30:00');

COMMIT TRANSACTION;

-- ---------------------------------------------------------------------
-- Resumen
-- ---------------------------------------------------------------------
SELECT 'Especies' AS Tabla, COUNT(*) AS Filas FROM Especies
UNION ALL SELECT 'Razas', COUNT(*) FROM Razas
UNION ALL SELECT 'ItemsClinicos', COUNT(*) FROM ItemsClinicos
UNION ALL SELECT 'Usuarios', COUNT(*) FROM Usuarios
UNION ALL SELECT 'Veterinarios', COUNT(*) FROM Veterinarios
UNION ALL SELECT 'Mascotas', COUNT(*) FROM Mascotas
UNION ALL SELECT 'AplicacionesVacuna', COUNT(*) FROM AplicacionesVacuna
UNION ALL SELECT 'AsignacionesTratamiento', COUNT(*) FROM AsignacionesTratamiento
UNION ALL SELECT 'NotasHistorial', COUNT(*) FROM NotasHistorial;
