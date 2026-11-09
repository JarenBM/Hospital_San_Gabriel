-- SIGIH | 04 - Stored procedures de Roles y Permisos
-- Convención: sp_Roles_<Accion> / sp_Permisos_<Accion>

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_Listar
    @solo_activos BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.id_rol,
           r.nombre,
           r.descripcion,
           r.activo,
           (SELECT COUNT(*) FROM dbo.RolesPermisos rp WHERE rp.id_rol = r.id_rol) AS total_permisos
    FROM dbo.Roles r
    WHERE (@solo_activos IS NULL OR r.activo = @solo_activos)
    ORDER BY r.nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_Obtener
    @id_rol INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.id_rol,
           r.nombre,
           r.descripcion,
           r.activo,
           (SELECT COUNT(*) FROM dbo.RolesPermisos rp WHERE rp.id_rol = r.id_rol) AS total_permisos
    FROM dbo.Roles r
    WHERE r.id_rol = @id_rol;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_Crear
    @nombre      NVARCHAR(50),
    @descripcion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
        THROW 52102, N'El nombre del rol es obligatorio', 1;

    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (TRIM(@nombre), @descripcion, 1);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_rol;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_Actualizar
    @id_rol      INT,
    @nombre      NVARCHAR(50),
    @descripcion NVARCHAR(255) = NULL,
    @activo      BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
        THROW 52102, N'El nombre del rol es obligatorio', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.Roles
        WHERE id_rol = @id_rol AND nombre = N'ADMINISTRADOR'
    )
    AND (TRIM(@nombre) <> N'ADMINISTRADOR' OR @activo = 0)
        THROW 52103, N'El rol ADMINISTRADOR no se puede renombrar ni desactivar', 1;

    UPDATE dbo.Roles
    SET nombre = TRIM(@nombre),
        descripcion = @descripcion,
        activo = COALESCE(@activo, activo)
    WHERE id_rol = @id_rol;

    IF @@ROWCOUNT = 0
        THROW 52101, N'Rol no encontrado', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_Desactivar
    @id_rol INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM dbo.Roles
        WHERE id_rol = @id_rol AND nombre = N'ADMINISTRADOR'
    )
        THROW 52103, N'El rol ADMINISTRADOR no se puede desactivar', 1;

    UPDATE dbo.Roles SET activo = 0 WHERE id_rol = @id_rol;

    IF @@ROWCOUNT = 0
        THROW 52101, N'Rol no encontrado', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_ListarPermisos
    @id_rol INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.id_permiso, p.codigo, p.modulo, p.descripcion
    FROM dbo.RolesPermisos rp
    JOIN dbo.Permisos p ON p.id_permiso = rp.id_permiso
    WHERE rp.id_rol = @id_rol
    ORDER BY p.modulo, p.codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_AsignarPermiso
    @id_rol     INT,
    @id_permiso INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol)
        THROW 52101, N'Rol no encontrado', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE id_permiso = @id_permiso)
        THROW 52104, N'Permiso no encontrado', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.RolesPermisos
        WHERE id_rol = @id_rol AND id_permiso = @id_permiso
    )
    BEGIN
        INSERT dbo.RolesPermisos (id_rol, id_permiso)
        VALUES (@id_rol, @id_permiso);
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_QuitarPermiso
    @id_rol     INT,
    @id_permiso INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol)
        THROW 52101, N'Rol no encontrado', 1;

    DELETE FROM dbo.RolesPermisos
    WHERE id_rol = @id_rol AND id_permiso = @id_permiso;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roles_SincronizarPermisos
    @id_rol       INT,
    @permisos_json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol)
        THROW 52101, N'Rol no encontrado', 1;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM dbo.RolesPermisos WHERE id_rol = @id_rol;

        INSERT dbo.RolesPermisos (id_rol, id_permiso)
        SELECT @id_rol, p.id_permiso
        FROM OPENJSON(ISNULL(@permisos_json, N'[]'))
             WITH (codigo NVARCHAR(80) '$') j
        JOIN dbo.Permisos p ON p.codigo = j.codigo;

        DECLARE @total INT = @@ROWCOUNT;
        COMMIT;

        SELECT @total AS total;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Permisos_Listar
    @modulo NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_permiso, codigo, modulo, descripcion
    FROM dbo.Permisos
    WHERE (@modulo IS NULL OR modulo = @modulo)
    ORDER BY modulo, codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Permisos_Obtener
    @id_permiso INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_permiso, codigo, modulo, descripcion
    FROM dbo.Permisos
    WHERE id_permiso = @id_permiso;
END;
GO

PRINT N'04_sp_roles_permisos.sql ejecutado.';
GO
