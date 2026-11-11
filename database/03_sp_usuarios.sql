-- SIGIH | 03 - Stored procedures de Usuarios
-- Convención: sp_Usuarios_<Accion>
-- Todos idempotentes con CREATE OR ALTER.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_ObtenerSesion
    @email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_usuario INT = (
        SELECT id_usuario FROM dbo.Usuarios WHERE email = @email
    );

    -- RS1: datos del usuario (el hash lo consume el backend, nunca el cliente)
    SELECT id_usuario, nombre, email, password_hash, activo
    FROM dbo.Usuarios
    WHERE id_usuario = @id_usuario;

    -- RS2: roles activos
    SELECT r.id_rol, r.nombre, r.activo
    FROM dbo.UsuariosRoles ur
    JOIN dbo.Roles r ON r.id_rol = ur.id_rol
    WHERE ur.id_usuario = @id_usuario
    ORDER BY r.nombre;

    -- RS3: permisos efectivos (solo roles activos)
    SELECT DISTINCT p.codigo, p.modulo
    FROM dbo.UsuariosRoles ur
    JOIN dbo.Roles r ON r.id_rol = ur.id_rol AND r.activo = 1
    JOIN dbo.RolesPermisos rp ON rp.id_rol = r.id_rol
    JOIN dbo.Permisos p ON p.id_permiso = rp.id_permiso
    WHERE ur.id_usuario = @id_usuario
    ORDER BY p.modulo, p.codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_Obtener
    @id_usuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.id_usuario,
           u.nombre,
           u.email,
           u.activo,
           u.fecha_creacion,
           (
               SELECT STRING_AGG(x.nombre, N', ') WITHIN GROUP (ORDER BY x.nombre)
               FROM (
                   SELECT DISTINCT r.nombre
                   FROM dbo.UsuariosRoles ur
                   JOIN dbo.Roles r ON r.id_rol = ur.id_rol
                   WHERE ur.id_usuario = u.id_usuario
               ) x
           ) AS roles
    FROM dbo.Usuarios u
    WHERE u.id_usuario = @id_usuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_Listar
    @busqueda     NVARCHAR(150) = NULL,
    @id_rol       INT           = NULL,
    @solo_activos BIT           = NULL,
    @pagina       INT           = NULL,
    @tamano       INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @offset INT = 0,
            @fetch  INT = 2147483647;

    IF @pagina IS NOT NULL OR @tamano IS NOT NULL
    BEGIN
        SET @pagina = ISNULL(@pagina, 1);
        SET @tamano = ISNULL(@tamano, 25);

        IF @pagina < 1 SET @pagina = 1;
        IF @tamano < 1 SET @tamano = 25;

        SET @offset = (@pagina - 1) * @tamano;
        SET @fetch  = @tamano;
    END

    SELECT u.id_usuario,
           u.nombre,
           u.email,
           u.activo,
           u.fecha_creacion,
           (
               SELECT STRING_AGG(x.nombre, N', ') WITHIN GROUP (ORDER BY x.nombre)
               FROM (
                   SELECT DISTINCT r.nombre
                   FROM dbo.UsuariosRoles ur
                   JOIN dbo.Roles r ON r.id_rol = ur.id_rol
                   WHERE ur.id_usuario = u.id_usuario
               ) x
           ) AS roles,
           COUNT(*) OVER () AS total
    FROM dbo.Usuarios u
    WHERE (@busqueda IS NULL
           OR u.nombre LIKE N'%' + @busqueda + N'%'
           OR u.email  LIKE N'%' + @busqueda + N'%')
      AND (@solo_activos IS NULL OR u.activo = @solo_activos)
      AND (@id_rol IS NULL
           OR EXISTS (
               SELECT 1
               FROM dbo.UsuariosRoles ur2
               WHERE ur2.id_usuario = u.id_usuario
                 AND ur2.id_rol = @id_rol
           ))
    ORDER BY u.nombre
    OFFSET @offset ROWS FETCH NEXT @fetch ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_Crear
    @nombre        NVARCHAR(100),
    @email         NVARCHAR(150),
    @password_hash NVARCHAR(255),
    @id_rol        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
       OR NULLIF(TRIM(@email), N'') IS NULL
       OR NULLIF(TRIM(@password_hash), N'') IS NULL
        THROW 52001, N'Datos de usuario incompletos', 1;

    IF @id_rol IS NOT NULL
       AND NOT EXISTS (
           SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol AND activo = 1
       )
        THROW 52002, N'Rol inválido o inactivo', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT dbo.Usuarios (nombre, email, password_hash, activo)
        VALUES (TRIM(@nombre), TRIM(@email), TRIM(@password_hash), 1);

        DECLARE @id_usuario INT = CAST(SCOPE_IDENTITY() AS INT);

        IF @id_rol IS NOT NULL
        BEGIN
            INSERT dbo.UsuariosRoles (id_usuario, id_rol)
            VALUES (@id_usuario, @id_rol);
        END;

        COMMIT;
        SELECT @id_usuario AS id_usuario;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_Actualizar
    @id_usuario INT,
    @nombre     NVARCHAR(100),
    @email      NVARCHAR(150),
    @activo     BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
       OR NULLIF(TRIM(@email), N'') IS NULL
        THROW 52001, N'Datos de usuario incompletos', 1;

    IF @activo = 0
       AND EXISTS (
           SELECT 1
           FROM dbo.UsuariosRoles ur
           JOIN dbo.Roles r ON r.id_rol = ur.id_rol
           WHERE ur.id_usuario = @id_usuario
             AND r.nombre = N'ADMINISTRADOR'
       )
       AND (
           SELECT COUNT(*)
           FROM dbo.Usuarios u
           JOIN dbo.UsuariosRoles ur ON ur.id_usuario = u.id_usuario
           JOIN dbo.Roles r ON r.id_rol = ur.id_rol
           WHERE r.nombre = N'ADMINISTRADOR'
             AND u.activo = 1
       ) <= 1
        THROW 52004, N'No se puede desactivar el último administrador activo', 1;

    UPDATE dbo.Usuarios
    SET nombre = TRIM(@nombre),
        email  = TRIM(@email),
        activo = COALESCE(@activo, activo)
    WHERE id_usuario = @id_usuario;

    IF @@ROWCOUNT = 0
        THROW 52003, N'Usuario no encontrado', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_Desactivar
    @id_usuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF EXISTS (
           SELECT 1
           FROM dbo.UsuariosRoles ur
           JOIN dbo.Roles r ON r.id_rol = ur.id_rol
           WHERE ur.id_usuario = @id_usuario
             AND r.nombre = N'ADMINISTRADOR'
       )
       AND (
           SELECT COUNT(*)
           FROM dbo.Usuarios u
           JOIN dbo.UsuariosRoles ur ON ur.id_usuario = u.id_usuario
           JOIN dbo.Roles r ON r.id_rol = ur.id_rol
           WHERE r.nombre = N'ADMINISTRADOR'
             AND u.activo = 1
       ) <= 1
        THROW 52004, N'No se puede desactivar el último administrador activo', 1;

    UPDATE dbo.Usuarios SET activo = 0 WHERE id_usuario = @id_usuario;

    IF @@ROWCOUNT = 0
        THROW 52003, N'Usuario no encontrado', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_CambiarPassword
    @id_usuario    INT,
    @password_hash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(TRIM(@password_hash), N'') IS NULL
        THROW 52001, N'El hash de contraseña es obligatorio', 1;

    UPDATE dbo.Usuarios
    SET password_hash = TRIM(@password_hash)
    WHERE id_usuario = @id_usuario;

    IF @@ROWCOUNT = 0
        THROW 52003, N'Usuario no encontrado', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_ListarRoles
    @id_usuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.id_rol, r.nombre, r.activo
    FROM dbo.UsuariosRoles ur
    JOIN dbo.Roles r ON r.id_rol = ur.id_rol
    WHERE ur.id_usuario = @id_usuario
    ORDER BY r.nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_ListarPermisos
    @id_usuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT p.codigo, p.modulo
    FROM dbo.UsuariosRoles ur
    JOIN dbo.Roles r ON r.id_rol = ur.id_rol AND r.activo = 1
    JOIN dbo.RolesPermisos rp ON rp.id_rol = r.id_rol
    JOIN dbo.Permisos p ON p.id_permiso = rp.id_permiso
    WHERE ur.id_usuario = @id_usuario
    ORDER BY p.modulo, p.codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_AsignarRol
    @id_usuario INT,
    @id_rol     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario)
        THROW 52003, N'Usuario no encontrado', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol AND activo = 1)
        THROW 52002, N'Rol inválido o inactivo', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.UsuariosRoles
        WHERE id_usuario = @id_usuario AND id_rol = @id_rol
    )
    BEGIN
        INSERT dbo.UsuariosRoles (id_usuario, id_rol)
        VALUES (@id_usuario, @id_rol);
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuarios_QuitarRol
    @id_usuario INT,
    @id_rol     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario)
        THROW 52003, N'Usuario no encontrado', 1;

    IF EXISTS (
           SELECT 1
           FROM dbo.Roles
           WHERE id_rol = @id_rol AND nombre = N'ADMINISTRADOR'
       )
       AND (
           SELECT COUNT(*)
           FROM dbo.Usuarios u
           JOIN dbo.UsuariosRoles ur ON ur.id_usuario = u.id_usuario
           JOIN dbo.Roles r ON r.id_rol = ur.id_rol
           WHERE r.nombre = N'ADMINISTRADOR'
             AND u.activo = 1
       ) <= 1
        THROW 52004, N'No se puede quitar el rol al último administrador activo', 1;

    DELETE FROM dbo.UsuariosRoles
    WHERE id_usuario = @id_usuario AND id_rol = @id_rol;
END;
GO

PRINT N'03_sp_usuarios.sql ejecutado.';
GO
