-- SIGIH | 16 - Usuario administrador inicial
-- Contraseña inicial: Admin.2026!
-- CAMBIAR ESTA CONTRASEÑA después del primer inicio de sesión.
-- El hash es Argon2id y se generó con argon2-cffi (PasswordHasher).
-- Idempotente: si el correo ya existe, no se duplica ni se sobreescribe.

USE SIGIH;
GO

IF NOT EXISTS (
    SELECT 1 FROM dbo.Usuarios
    WHERE email = N'admin.desarrollo@sigih.test'
)
BEGIN
    INSERT dbo.Usuarios (nombre, email, password_hash, activo)
    VALUES
    (
        N'Administrador Desarrollo',
        N'admin.desarrollo@sigih.test',
        N'$argon2id$v=19$m=65536,t=3,p=4$YzooompV1HQBUjOmyRNQPw$JOP3VKvGL63VJMPaHWdEaODlXIMUowIOu3ZPrrheZyk',
        1
    );
END;

-- Rol ADMINISTRADOR para el usuario inicial.
IF EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ADMINISTRADOR')
BEGIN
    INSERT dbo.UsuariosRoles (id_usuario, id_rol)
    SELECT u.id_usuario, r.id_rol
    FROM dbo.Usuarios u
    JOIN dbo.Roles r ON r.nombre = N'ADMINISTRADOR'
    WHERE u.email = N'admin.desarrollo@sigih.test'
      AND NOT EXISTS (
          SELECT 1 FROM dbo.UsuariosRoles ur
          WHERE ur.id_usuario = u.id_usuario AND ur.id_rol = r.id_rol
      );
END;

PRINT N'16_admin_inicial.sql ejecutado.';
GO
