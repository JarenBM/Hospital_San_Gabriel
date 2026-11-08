-- ============================================================================
-- SIGIH · Sistema de Gestión de Inventario Hospitalario
-- INSTALACIÓN COMPLETA DE LA BASE DE DATOS (un solo archivo)
-- ============================================================================
--
-- Reúne, en orden, todos los scripts de la carpeta database/:
--   00  creación de la base SIGIH
--   01  tablas base e índices
--   02  tablas RBAC y auditoría
--   03  a 13  stored procedures y wrappers legacy
--   14  a 16  catálogos, roles/permisos y administrador inicial
--   17  login y usuario de aplicación sigih_app
--   18  datos de demostración (categorías, áreas, productos y movimientos)
--   99  verificación final de la instalación
--
-- CÓMO USARLO
--
--   Opción A · SQL Server Management Studio (SSMS)
--     1. Conéctese a .\SQLEXPRESS con autenticación de Windows.
--     2. Abra este archivo (Archivo > Abrir > Archivo) y pulse F5.
--     3. Revise la pestaña Mensajes: no debe haber errores en rojo y al final
--        aparecerá el resumen de verificación y el mensaje de finalización.
--
--   Opción B · sqlcmd (recomendada para adjuntar por consola)
--     cd C:\ruta\del\proyecto
--     sqlcmd -S .\SQLEXPRESS -E -C -b -I -f 65001 -i database\INSTALAR_SIGIH.sql
--
-- CONTRASEÑA DEL USUARIO DE APLICACIÓN
--   Más abajo se crea el login sigih_app. La contraseña se define en:
--       DECLARE @password NVARCHAR(128) = N'Sigih.App.2026!';
--   Si la cambia en este archivo, escriba exactamente la misma en
--   backend/.env como DB_PASSWORD. Si no la cambia, deje ese mismo valor.
--
--   ATENCIÓN: si la base ya estaba instalada, este script cambia la
--   contraseña del login sigih_app por la definida aquí. Antes de ejecutarlo
--   en un equipo que ya funciona, ajuste esa línea al valor de su .env.
--
-- NOTAS
--   * Es idempotente: se puede ejecutar varias veces sin duplicar datos.
--   * No elimina información existente.
--   * Requiere permisos de sysadmin (CREATE DATABASE y CREATE LOGIN).
--   * Codificación UTF-8: en sqlcmd use -f 65001; SSMS lo detecta solo.
--   * Tiempo estimado de ejecución: menos de 10 segundos.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO


-- ============================================================================
-- 00_crear_base.sql
-- ============================================================================

-- SIGIH | 00 - Creación de la base de datos
-- Idempotente: se puede ejecutar varias veces.
-- Ejecutar con: sqlcmd -S .\SQLEXPRESS -E -C -i database\00_crear_base.sql

IF DB_ID(N'SIGIH') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE SIGIH');
END;
GO

USE SIGIH;
GO

PRINT N'Base de datos SIGIH lista.';
GO


-- ============================================================================
-- 01_tablas_base.sql
-- ============================================================================

-- SIGIH | 01 - Tablas base del esquema existente
-- Idempotente: solo crea lo que no existe. No altera tablas ya creadas.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios
    (
        id_usuario    INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Usuarios PRIMARY KEY,
        nombre        NVARCHAR(100) NOT NULL,
        email         NVARCHAR(150) NOT NULL
            CONSTRAINT UQ_Usuarios_Email UNIQUE,
        password_hash NVARCHAR(255) NOT NULL,
        activo        BIT NOT NULL
            CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
        fecha_creacion DATETIME2 NOT NULL
            CONSTRAINT DF_Usuarios_Fecha DEFAULT (SYSDATETIME())
    );
END;
GO

IF OBJECT_ID(N'dbo.Categorias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Categorias
    (
        id_categoria INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Categorias PRIMARY KEY,
        nombre       NVARCHAR(100) NOT NULL
            CONSTRAINT UQ_Categorias_Nombre UNIQUE,
        descripcion  NVARCHAR(255) NULL,
        activo       BIT NOT NULL
            CONSTRAINT DF_Categorias_Activo DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Productos
    (
        id_producto         INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Productos PRIMARY KEY,
        id_categoria        INT NOT NULL
            CONSTRAINT FK_Productos_Categorias REFERENCES dbo.Categorias(id_categoria),
        codigo              NVARCHAR(30) NOT NULL
            CONSTRAINT UQ_Productos_Codigo UNIQUE,
        nombre              NVARCHAR(150) NOT NULL,
        descripcion         NVARCHAR(500) NULL,
        unidad_medida       NVARCHAR(30) NOT NULL,
        precio_unitario     DECIMAL(12,2) NOT NULL
            CONSTRAINT CK_Productos_Precio CHECK (precio_unitario > 0),
        stock_minimo        INT NOT NULL
            CONSTRAINT DF_Productos_StockMinimo DEFAULT (0)
            CONSTRAINT CK_Productos_StockMinimo CHECK (stock_minimo >= 0),
        maneja_lotes        BIT NOT NULL
            CONSTRAINT DF_Productos_ManejaLotes DEFAULT (0),
        requiere_vencimiento BIT NOT NULL
            CONSTRAINT DF_Productos_RequiereVencimiento DEFAULT (0),
        activo              BIT NOT NULL
            CONSTRAINT DF_Productos_Activo DEFAULT (1),
        CONSTRAINT CK_Producto_Vence CHECK (requiere_vencimiento = 0 OR maneja_lotes = 1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Lotes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Lotes
    (
        id_lote           INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Lotes PRIMARY KEY,
        id_producto       INT NOT NULL
            CONSTRAINT FK_Lotes_Productos REFERENCES dbo.Productos(id_producto),
        numero_lote       NVARCHAR(50) NULL,
        fecha_vencimiento DATE NULL,
        stock_actual      INT NOT NULL
            CONSTRAINT DF_Lotes_Stock DEFAULT (0)
            CONSTRAINT CK_Lotes_Stock CHECK (stock_actual >= 0),
        fecha_registro    DATETIME2 NOT NULL
            CONSTRAINT DF_Lotes_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_LoteProducto UNIQUE (id_producto, id_lote)
    );
END;
GO

IF OBJECT_ID(N'dbo.AreasHospitalarias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AreasHospitalarias
    (
        id_area INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_AreasHospitalarias PRIMARY KEY,
        nombre  NVARCHAR(100) NOT NULL
            CONSTRAINT UQ_AreasHospitalarias_Nombre UNIQUE,
        activo  BIT NOT NULL
            CONSTRAINT DF_AreasHospitalarias_Activo DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Movimientos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Movimientos
    (
        id_movimiento    INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Movimientos PRIMARY KEY,
        id_producto      INT NOT NULL
            CONSTRAINT FK_Movimientos_Productos REFERENCES dbo.Productos(id_producto),
        id_lote          INT NOT NULL,
        id_usuario       INT NOT NULL
            CONSTRAINT FK_Movimientos_Usuarios REFERENCES dbo.Usuarios(id_usuario),
        id_area          INT NULL
            CONSTRAINT FK_Movimientos_Areas REFERENCES dbo.AreasHospitalarias(id_area),
        tipo_movimiento  VARCHAR(10) NOT NULL
            CONSTRAINT CK_Movimientos_Tipo CHECK (tipo_movimiento IN ('ENTRADA','SALIDA')),
        cantidad         INT NOT NULL
            CONSTRAINT CK_Movimientos_Cantidad CHECK (cantidad > 0),
        fecha_movimiento DATETIME2 NOT NULL
            CONSTRAINT DF_Movimientos_Fecha DEFAULT (SYSDATETIME()),
        motivo           NVARCHAR(200) NOT NULL,
        stock_anterior   INT NOT NULL
            CONSTRAINT CK_Movimientos_StockAnterior CHECK (stock_anterior >= 0),
        stock_posterior  INT NOT NULL
            CONSTRAINT CK_Movimientos_StockPosterior CHECK (stock_posterior >= 0),
        CONSTRAINT FK_Mov_LoteProducto
            FOREIGN KEY (id_producto, id_lote) REFERENCES dbo.Lotes(id_producto, id_lote),
        CONSTRAINT CK_Mov_Area CHECK (
            (tipo_movimiento = 'ENTRADA' AND id_area IS NULL)
            OR (tipo_movimiento = 'SALIDA' AND id_area IS NOT NULL)
        ),
        CONSTRAINT CK_Mov_Cambio CHECK (
            (tipo_movimiento = 'ENTRADA' AND stock_posterior = stock_anterior + cantidad)
            OR (tipo_movimiento = 'SALIDA' AND stock_anterior = stock_posterior + cantidad)
        )
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Lote_Numero' AND object_id = OBJECT_ID(N'dbo.Lotes'))
BEGIN
    CREATE UNIQUE INDEX UX_Lote_Numero
        ON dbo.Lotes(id_producto, numero_lote)
        WHERE numero_lote IS NOT NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Lote_SinNumero' AND object_id = OBJECT_ID(N'dbo.Lotes'))
BEGIN
    CREATE UNIQUE INDEX UX_Lote_SinNumero
        ON dbo.Lotes(id_producto)
        WHERE numero_lote IS NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Productos_Categoria' AND object_id = OBJECT_ID(N'dbo.Productos'))
    CREATE INDEX IX_Productos_Categoria ON dbo.Productos(id_categoria);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Lotes_Vencimiento' AND object_id = OBJECT_ID(N'dbo.Lotes'))
    CREATE INDEX IX_Lotes_Vencimiento ON dbo.Lotes(fecha_vencimiento, id_producto) INCLUDE(stock_actual);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Producto_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Producto_Fecha ON dbo.Movimientos(id_producto, fecha_movimiento DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Tipo_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Tipo_Fecha ON dbo.Movimientos(tipo_movimiento, fecha_movimiento DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Area_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Area_Fecha ON dbo.Movimientos(id_area, fecha_movimiento DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Usuario_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Usuario_Fecha ON dbo.Movimientos(id_usuario, fecha_movimiento DESC);
GO

PRINT N'01_tablas_base.sql ejecutado.';
GO


-- ============================================================================
-- 02_rbac_tablas.sql
-- ============================================================================

-- SIGIH | 02 - Tablas de seguridad: RBAC y auditoría
-- Idempotente. No modifica tablas base existentes.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.Roles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Roles
    (
        id_rol      INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Roles PRIMARY KEY,
        nombre      NVARCHAR(50) NOT NULL
            CONSTRAINT UQ_Roles_Nombre UNIQUE,
        descripcion NVARCHAR(255) NULL,
        activo      BIT NOT NULL
            CONSTRAINT DF_Roles_Activo DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Permisos
    (
        id_permiso  INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Permisos PRIMARY KEY,
        codigo      NVARCHAR(80) NOT NULL
            CONSTRAINT UQ_Permisos_Codigo UNIQUE,
        modulo      NVARCHAR(50) NOT NULL,
        descripcion NVARCHAR(255) NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.RolesPermisos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RolesPermisos
    (
        id_rol      INT NOT NULL
            CONSTRAINT FK_RolesPermisos_Roles REFERENCES dbo.Roles(id_rol),
        id_permiso  INT NOT NULL
            CONSTRAINT FK_RolesPermisos_Permisos REFERENCES dbo.Permisos(id_permiso),
        CONSTRAINT PK_RolesPermisos PRIMARY KEY (id_rol, id_permiso)
    );
END;
GO

IF OBJECT_ID(N'dbo.UsuariosRoles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.UsuariosRoles
    (
        id_usuario INT NOT NULL
            CONSTRAINT FK_UsuariosRoles_Usuarios REFERENCES dbo.Usuarios(id_usuario),
        id_rol     INT NOT NULL
            CONSTRAINT FK_UsuariosRoles_Roles REFERENCES dbo.Roles(id_rol),
        CONSTRAINT PK_UsuariosRoles PRIMARY KEY (id_usuario, id_rol)
    );
END;
GO

IF OBJECT_ID(N'dbo.Auditoria', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Auditoria
    (
        id_auditoria BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Auditoria PRIMARY KEY,
        id_usuario   INT NULL
            CONSTRAINT FK_Auditoria_Usuarios REFERENCES dbo.Usuarios(id_usuario),
        accion       NVARCHAR(50) NOT NULL,
        modulo       NVARCHAR(50) NOT NULL,
        id_registro  NVARCHAR(50) NULL,
        detalle      NVARCHAR(500) NULL,
        ip           NVARCHAR(45) NULL,
        fecha        DATETIME2 NOT NULL
            CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME())
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_UsuariosRoles_Rol' AND object_id = OBJECT_ID(N'dbo.UsuariosRoles'))
    CREATE INDEX IX_UsuariosRoles_Rol ON dbo.UsuariosRoles(id_rol);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RolesPermisos_Permiso' AND object_id = OBJECT_ID(N'dbo.RolesPermisos'))
    CREATE INDEX IX_RolesPermisos_Permiso ON dbo.RolesPermisos(id_permiso);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Auditoria_Fecha' AND object_id = OBJECT_ID(N'dbo.Auditoria'))
    CREATE INDEX IX_Auditoria_Fecha ON dbo.Auditoria(fecha DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Auditoria_Usuario' AND object_id = OBJECT_ID(N'dbo.Auditoria'))
    CREATE INDEX IX_Auditoria_Usuario ON dbo.Auditoria(id_usuario, fecha DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Auditoria_Modulo' AND object_id = OBJECT_ID(N'dbo.Auditoria'))
    CREATE INDEX IX_Auditoria_Modulo ON dbo.Auditoria(modulo, fecha DESC);
GO

PRINT N'02_rbac_tablas.sql ejecutado.';
GO


-- ============================================================================
-- 03_sp_usuarios.sql
-- ============================================================================

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
    @solo_activos BIT           = NULL
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
    ORDER BY u.nombre;
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


-- ============================================================================
-- 04_sp_roles_permisos.sql
-- ============================================================================

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


-- ============================================================================
-- 05_sp_categorias.sql
-- ============================================================================

-- SIGIH | 05 - Stored procedures de Categorías
-- Convención: sp_Categorias_<Accion>

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categorias_Listar
    @solo_activos BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_categoria, nombre, descripcion, activo
    FROM dbo.Categorias
    WHERE (@solo_activos IS NULL OR activo = @solo_activos)
    ORDER BY nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categorias_Obtener
    @id_categoria INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_categoria, nombre, descripcion, activo
    FROM dbo.Categorias
    WHERE id_categoria = @id_categoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categorias_Crear
    @nombre      NVARCHAR(100),
    @descripcion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
        THROW 51401, N'El nombre de la categoría es obligatorio', 1;

    INSERT dbo.Categorias (nombre, descripcion, activo)
    VALUES (TRIM(@nombre), @descripcion, 1);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_categoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categorias_Actualizar
    @id_categoria INT,
    @nombre       NVARCHAR(100),
    @descripcion  NVARCHAR(255) = NULL,
    @activo       BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
        THROW 51401, N'El nombre de la categoría es obligatorio', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.Categorias
        WHERE nombre = TRIM(@nombre) AND id_categoria <> @id_categoria
    )
        THROW 51402, N'Ya existe una categoría con ese nombre', 1;

    IF @activo = 0
       AND EXISTS (
           SELECT 1 FROM dbo.Productos
           WHERE id_categoria = @id_categoria AND activo = 1
       )
        THROW 51404, N'La categoría tiene productos activos', 1;

    UPDATE dbo.Categorias
    SET nombre = TRIM(@nombre),
        descripcion = @descripcion,
        activo = COALESCE(@activo, activo)
    WHERE id_categoria = @id_categoria;

    IF @@ROWCOUNT = 0
        THROW 51403, N'Categoría no encontrada', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categorias_Desactivar
    @id_categoria INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM dbo.Productos
        WHERE id_categoria = @id_categoria AND activo = 1
    )
        THROW 51404, N'La categoría tiene productos activos', 1;

    UPDATE dbo.Categorias SET activo = 0 WHERE id_categoria = @id_categoria;

    IF @@ROWCOUNT = 0
        THROW 51403, N'Categoría no encontrada', 1;
END;
GO

PRINT N'05_sp_categorias.sql ejecutado.';
GO


-- ============================================================================
-- 06_sp_productos.sql
-- ============================================================================

-- SIGIH | 06 - Stored procedures de Productos
-- Convención: sp_Productos_<Accion>
-- Códigos: 51002-51009 (productos).

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Productos_Listar
    @busqueda     NVARCHAR(150) = NULL,
    @id_categoria INT           = NULL,
    @solo_activos BIT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.id_producto,
           p.codigo,
           p.nombre,
           p.descripcion,
           p.id_categoria,
           c.nombre AS categoria,
           p.unidad_medida,
           p.precio_unitario,
           p.stock_minimo,
           p.maneja_lotes,
           p.requiere_vencimiento,
           p.activo,
           COALESCE(s.stock_total, 0)      AS stock_total,
           COALESCE(s.stock_disponible, 0) AS stock_disponible
    FROM dbo.Productos p
    JOIN dbo.Categorias c ON c.id_categoria = p.id_categoria
    OUTER APPLY (
        SELECT SUM(l.stock_actual) AS stock_total,
               SUM(CASE
                       WHEN l.fecha_vencimiento IS NULL
                            OR l.fecha_vencimiento >= CONVERT(date, GETDATE())
                       THEN l.stock_actual
                       ELSE 0
                   END) AS stock_disponible
        FROM dbo.Lotes l
        WHERE l.id_producto = p.id_producto
    ) s
    WHERE (@busqueda IS NULL
           OR p.codigo LIKE N'%' + @busqueda + N'%'
           OR p.nombre LIKE N'%' + @busqueda + N'%')
      AND (@id_categoria IS NULL OR p.id_categoria = @id_categoria)
      AND (@solo_activos IS NULL OR p.activo = @solo_activos)
    ORDER BY p.nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Productos_Obtener
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_producto,
           id_categoria,
           codigo,
           nombre,
           descripcion,
           unidad_medida,
           precio_unitario,
           stock_minimo,
           maneja_lotes,
           requiere_vencimiento,
           activo
    FROM dbo.Productos
    WHERE id_producto = @id_producto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Productos_Crear
    @id_categoria        INT,
    @codigo              NVARCHAR(30),
    @nombre              NVARCHAR(150),
    @descripcion         NVARCHAR(500) = NULL,
    @unidad_medida       NVARCHAR(30),
    @precio_unitario     DECIMAL(12,2),
    @stock_minimo        INT = 0,
    @maneja_lotes        BIT = 0,
    @requiere_vencimiento BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Categorias
        WHERE id_categoria = @id_categoria AND activo = 1
    )
        THROW 51003, N'Categoría no válida o inactiva', 1;

    IF NULLIF(TRIM(@codigo), N'') IS NULL
       OR NULLIF(TRIM(@nombre), N'') IS NULL
       OR NULLIF(TRIM(@unidad_medida), N'') IS NULL
        THROW 51004, N'Campos obligatorios del producto incompletos', 1;

    IF @precio_unitario IS NULL OR @precio_unitario <= 0
        THROW 51004, N'El precio unitario debe ser mayor que cero', 1;

    IF @stock_minimo IS NULL OR @stock_minimo < 0
        THROW 51004, N'El stock mínimo no puede ser negativo', 1;

    IF @requiere_vencimiento = 1 AND @maneja_lotes = 0
        THROW 51004, N'Un producto con vencimiento debe manejar lotes', 1;

    INSERT dbo.Productos
    (
        id_categoria, codigo, nombre, descripcion, unidad_medida,
        precio_unitario, stock_minimo, maneja_lotes, requiere_vencimiento, activo
    )
    VALUES
    (
        @id_categoria, TRIM(@codigo), TRIM(@nombre), @descripcion,
        TRIM(@unidad_medida), @precio_unitario, @stock_minimo,
        @maneja_lotes, @requiere_vencimiento, 1
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_producto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Productos_Actualizar
    @id_producto     INT,
    @id_categoria    INT,
    @codigo          NVARCHAR(30),
    @nombre          NVARCHAR(150),
    @descripcion     NVARCHAR(500) = NULL,
    @unidad_medida   NVARCHAR(30),
    @precio_unitario DECIMAL(12,2),
    @stock_minimo    INT,
    @activo          BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Categorias
        WHERE id_categoria = @id_categoria AND activo = 1
    )
        THROW 51005, N'Categoría no válida o inactiva', 1;

    IF NULLIF(TRIM(@codigo), N'') IS NULL
       OR NULLIF(TRIM(@nombre), N'') IS NULL
       OR NULLIF(TRIM(@unidad_medida), N'') IS NULL
        THROW 51006, N'Campos obligatorios del producto incompletos', 1;

    IF @precio_unitario IS NULL OR @precio_unitario <= 0
        THROW 51006, N'El precio unitario debe ser mayor que cero', 1;

    IF @stock_minimo IS NULL OR @stock_minimo < 0
        THROW 51006, N'El stock mínimo no puede ser negativo', 1;

    UPDATE dbo.Productos
    SET id_categoria    = @id_categoria,
        codigo          = TRIM(@codigo),
        nombre          = TRIM(@nombre),
        descripcion     = @descripcion,
        unidad_medida   = TRIM(@unidad_medida),
        precio_unitario = @precio_unitario,
        stock_minimo    = @stock_minimo,
        activo          = COALESCE(@activo, activo)
    WHERE id_producto = @id_producto;

    IF @@ROWCOUNT = 0
        THROW 51007, N'Producto no encontrado', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Productos_Desactivar
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE id_producto = @id_producto)
        THROW 51008, N'Producto no encontrado', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.Lotes
        WHERE id_producto = @id_producto
          AND stock_actual > 0
    )
        THROW 51009, N'No se puede desactivar un producto con existencias', 1;

    UPDATE dbo.Productos SET activo = 0 WHERE id_producto = @id_producto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Productos_Reactivar
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Productos SET activo = 1 WHERE id_producto = @id_producto;

    IF @@ROWCOUNT = 0
        THROW 51007, N'Producto no encontrado', 1;
END;
GO

PRINT N'06_sp_productos.sql ejecutado.';
GO


-- ============================================================================
-- 07_sp_lotes.sql
-- ============================================================================

-- SIGIH | 07 - Stored procedures de Lotes
-- Convención: sp_Lotes_<Accion>
-- El stock de un lote solo cambia mediante entradas y salidas (08).

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Lotes_ListarPorProducto
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_lote,
           id_producto,
           numero_lote,
           fecha_vencimiento,
           stock_actual,
           fecha_registro,
           CASE
               WHEN fecha_vencimiento < CONVERT(date, GETDATE()) THEN 1
               ELSE 0
           END AS vencido
    FROM dbo.Lotes
    WHERE id_producto = @id_producto
    ORDER BY fecha_vencimiento, id_lote;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Lotes_Obtener
    @id_lote INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_lote,
           id_producto,
           numero_lote,
           fecha_vencimiento,
           stock_actual,
           fecha_registro,
           CASE
               WHEN fecha_vencimiento < CONVERT(date, GETDATE()) THEN 1
               ELSE 0
           END AS vencido
    FROM dbo.Lotes
    WHERE id_lote = @id_lote;
END;
GO

PRINT N'07_sp_lotes.sql ejecutado.';
GO


-- ============================================================================
-- 08_sp_movimientos.sql
-- ============================================================================

-- SIGIH | 08 - Stored procedures de Movimientos
-- Convención: sp_Movimientos_<Accion>
-- Las transacciones de stock viven aquí: BEGIN TRAN + XACT_ABORT + ROLLBACK.
-- Códigos: 511xx entradas, 512xx salidas.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_RegistrarEntrada
    @id_producto        INT,
    @id_usuario         INT,
    @cantidad           INT,
    @motivo             NVARCHAR(200),
    @numero_lote        NVARCHAR(50) = NULL,
    @fecha_vencimiento  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maneja BIT,
            @requiere BIT,
            @id_lote INT,
            @prev INT,
            @nuevo INT,
            @fecha_existente DATE,
            @numero_existente NVARCHAR(50);

    BEGIN TRY
        BEGIN TRAN;

        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 51101, N'Cantidad inválida', 1;

        IF NULLIF(TRIM(@motivo), N'') IS NULL
            THROW 51102, N'Motivo obligatorio', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Usuarios
            WHERE id_usuario = @id_usuario AND activo = 1
        )
            THROW 51103, N'Usuario inválido o inactivo', 1;

        SELECT @maneja = maneja_lotes,
               @requiere = requiere_vencimiento
        FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
        WHERE id_producto = @id_producto AND activo = 1;

        IF @maneja IS NULL
            THROW 51104, N'Producto inválido o inactivo', 1;

        SET @numero_lote = NULLIF(TRIM(@numero_lote), N'');

        IF @maneja = 1 AND @numero_lote IS NULL
            THROW 51105, N'Número de lote obligatorio', 1;

        IF @maneja = 0 AND (@numero_lote IS NOT NULL OR @fecha_vencimiento IS NOT NULL)
            THROW 51106, N'El producto no maneja lotes', 1;

        IF @requiere = 1 AND @fecha_vencimiento IS NULL
            THROW 51107, N'Fecha de vencimiento obligatoria', 1;

        IF @fecha_vencimiento IS NOT NULL
           AND @fecha_vencimiento < CONVERT(date, GETDATE())
            THROW 51108, N'No se admite el ingreso de un lote vencido', 1;

        SELECT @prev = COALESCE(SUM(stock_actual), 0)
        FROM dbo.Lotes
        WHERE id_producto = @id_producto;

        SELECT @id_lote = id_lote,
               @fecha_existente = fecha_vencimiento,
               @numero_existente = numero_lote
        FROM dbo.Lotes WITH (UPDLOCK, HOLDLOCK)
        WHERE id_producto = @id_producto
          AND (
                (@numero_lote IS NULL AND numero_lote IS NULL)
                OR numero_lote = @numero_lote
              );

        IF @id_lote IS NOT NULL
        BEGIN
            IF (@fecha_existente <> @fecha_vencimiento)
               OR (@fecha_existente IS NULL AND @fecha_vencimiento IS NOT NULL)
               OR (@fecha_existente IS NOT NULL AND @fecha_vencimiento IS NULL)
                THROW 51109, N'El vencimiento no coincide con el lote existente', 1;

            UPDATE dbo.Lotes
            SET stock_actual = stock_actual + @cantidad
            WHERE id_lote = @id_lote;
        END
        ELSE
        BEGIN
            INSERT dbo.Lotes (id_producto, numero_lote, fecha_vencimiento, stock_actual)
            VALUES (@id_producto, @numero_lote, @fecha_vencimiento, @cantidad);

            SET @id_lote = CAST(SCOPE_IDENTITY() AS INT);
        END;

        SET @nuevo = @prev + @cantidad;

        INSERT dbo.Movimientos
        (
            id_producto, id_lote, id_usuario, id_area, tipo_movimiento,
            cantidad, motivo, stock_anterior, stock_posterior
        )
        VALUES
        (
            @id_producto, @id_lote, @id_usuario, NULL, 'ENTRADA',
            @cantidad, @motivo, @prev, @nuevo
        );

        DECLARE @id_movimiento INT = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT;

        SELECT @id_movimiento AS id_movimiento,
               @id_lote AS id_lote,
               @prev AS stock_anterior,
               @nuevo AS stock_posterior;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_RegistrarSalida
    @id_producto INT,
    @id_lote     INT,
    @id_usuario  INT,
    @id_area     INT,
    @cantidad    INT,
    @motivo      NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @requiere BIT,
            @stock_lote INT,
            @vence DATE,
            @prev INT,
            @nuevo INT;

    BEGIN TRY
        BEGIN TRAN;

        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 51201, N'Cantidad inválida', 1;

        IF NULLIF(TRIM(@motivo), N'') IS NULL
            THROW 51202, N'Motivo obligatorio', 1;

        SELECT @requiere = requiere_vencimiento
        FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
        WHERE id_producto = @id_producto AND activo = 1;

        IF @requiere IS NULL
            THROW 51203, N'Producto inválido o inactivo', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Usuarios
            WHERE id_usuario = @id_usuario AND activo = 1
        )
            THROW 51204, N'Usuario inválido o inactivo', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.AreasHospitalarias
            WHERE id_area = @id_area AND activo = 1
        )
            THROW 51205, N'Área inválida o inactiva', 1;

        SELECT @stock_lote = stock_actual,
               @vence = fecha_vencimiento
        FROM dbo.Lotes WITH (UPDLOCK, HOLDLOCK)
        WHERE id_lote = @id_lote AND id_producto = @id_producto;

        IF @stock_lote IS NULL
            THROW 51206, N'Lote no encontrado', 1;

        IF @requiere = 1 AND @vence IS NULL
            THROW 51207, N'El lote no tiene fecha de vencimiento', 1;

        IF @vence < CONVERT(date, GETDATE())
            THROW 51208, N'El lote está vencido', 1;

        IF @stock_lote < @cantidad
            THROW 51209, N'Stock insuficiente en el lote', 1;

        SELECT @prev = COALESCE(SUM(stock_actual), 0)
        FROM dbo.Lotes
        WHERE id_producto = @id_producto;

        UPDATE dbo.Lotes
        SET stock_actual = stock_actual - @cantidad
        WHERE id_lote = @id_lote
          AND stock_actual >= @cantidad;

        IF @@ROWCOUNT <> 1
            THROW 51210, N'El stock cambió durante la operación', 1;

        SET @nuevo = @prev - @cantidad;

        INSERT dbo.Movimientos
        (
            id_producto, id_lote, id_usuario, id_area, tipo_movimiento,
            cantidad, motivo, stock_anterior, stock_posterior
        )
        VALUES
        (
            @id_producto, @id_lote, @id_usuario, @id_area, 'SALIDA',
            @cantidad, @motivo, @prev, @nuevo
        );

        DECLARE @id_movimiento INT = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT;

        SELECT @id_movimiento AS id_movimiento,
               @prev AS stock_anterior,
               @nuevo AS stock_posterior;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_Listar
    @id_producto     INT = NULL,
    @tipo_movimiento VARCHAR(10) = NULL,
    @id_area         INT = NULL,
    @desde           DATE = NULL,
    @hasta           DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.id_movimiento,
           m.fecha_movimiento,
           m.tipo_movimiento,
           p.codigo,
           p.nombre AS producto,
           l.numero_lote,
           l.fecha_vencimiento,
           a.nombre AS area,
           u.nombre AS usuario,
           m.cantidad,
           m.motivo,
           m.stock_anterior,
           m.stock_posterior
    FROM dbo.Movimientos m
    JOIN dbo.Productos p ON p.id_producto = m.id_producto
    JOIN dbo.Lotes l ON l.id_lote = m.id_lote
    JOIN dbo.Usuarios u ON u.id_usuario = m.id_usuario
    LEFT JOIN dbo.AreasHospitalarias a ON a.id_area = m.id_area
    WHERE (@id_producto IS NULL OR m.id_producto = @id_producto)
      AND (@tipo_movimiento IS NULL OR m.tipo_movimiento = @tipo_movimiento)
      AND (@id_area IS NULL OR m.id_area = @id_area)
      AND (@desde IS NULL OR m.fecha_movimiento >= @desde)
      AND (@hasta IS NULL
           OR m.fecha_movimiento < DATEADD(day, 1, CAST(@hasta AS DATETIME2)))
    ORDER BY m.fecha_movimiento DESC, m.id_movimiento DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_Obtener
    @id_movimiento INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.id_movimiento,
           m.fecha_movimiento,
           m.tipo_movimiento,
           p.codigo,
           p.nombre AS producto,
           l.numero_lote,
           l.fecha_vencimiento,
           a.nombre AS area,
           u.nombre AS usuario,
           m.cantidad,
           m.motivo,
           m.stock_anterior,
           m.stock_posterior
    FROM dbo.Movimientos m
    JOIN dbo.Productos p ON p.id_producto = m.id_producto
    JOIN dbo.Lotes l ON l.id_lote = m.id_lote
    JOIN dbo.Usuarios u ON u.id_usuario = m.id_usuario
    LEFT JOIN dbo.AreasHospitalarias a ON a.id_area = m.id_area
    WHERE m.id_movimiento = @id_movimiento;
END;
GO

PRINT N'08_sp_movimientos.sql ejecutado.';
GO


-- ============================================================================
-- 09_sp_areas.sql
-- ============================================================================

-- SIGIH | 09 - Stored procedures de Áreas hospitalarias
-- Convención: sp_Areas_<Accion>
-- Códigos: 51501-51503.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Areas_Listar
    @solo_activos BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_area, nombre, activo
    FROM dbo.AreasHospitalarias
    WHERE (@solo_activos IS NULL OR activo = @solo_activos)
    ORDER BY nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Areas_Obtener
    @id_area INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_area, nombre, activo
    FROM dbo.AreasHospitalarias
    WHERE id_area = @id_area;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Areas_Crear
    @nombre NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
        THROW 51501, N'El nombre del área es obligatorio', 1;

    INSERT dbo.AreasHospitalarias (nombre, activo)
    VALUES (TRIM(@nombre), 1);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_area;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Areas_Actualizar
    @id_area INT,
    @nombre  NVARCHAR(100),
    @activo  BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(TRIM(@nombre), N'') IS NULL
        THROW 51501, N'El nombre del área es obligatorio', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.AreasHospitalarias
        WHERE nombre = TRIM(@nombre) AND id_area <> @id_area
    )
        THROW 51502, N'Ya existe un área con ese nombre', 1;

    UPDATE dbo.AreasHospitalarias
    SET nombre = TRIM(@nombre),
        activo = COALESCE(@activo, activo)
    WHERE id_area = @id_area;

    IF @@ROWCOUNT = 0
        THROW 51503, N'Área no encontrada', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Areas_Desactivar
    @id_area INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.AreasHospitalarias SET activo = 0 WHERE id_area = @id_area;

    IF @@ROWCOUNT = 0
        THROW 51503, N'Área no encontrada', 1;
END;
GO

PRINT N'09_sp_areas.sql ejecutado.';
GO


-- ============================================================================
-- 10_sp_alertas_dashboard.sql
-- ============================================================================

-- SIGIH | 10 - Alertas y dashboard (solo lectura)
-- Convención: sp_Alertas_<Accion> / sp_Dashboard_<Accion>
-- sp_Alertas_PorVencer conserva el comportamiento legacy: devuelve PROXIMO y VENCIDO.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Alertas_StockBajo
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.id_producto,
           p.codigo,
           p.nombre,
           p.stock_minimo,
           COALESCE(
               SUM(CASE
                       WHEN l.fecha_vencimiento IS NULL
                            OR l.fecha_vencimiento >= CONVERT(date, GETDATE())
                       THEN l.stock_actual
                       ELSE 0
                   END), 0
           ) AS stock_disponible
    FROM dbo.Productos p
    LEFT JOIN dbo.Lotes l ON l.id_producto = p.id_producto
    WHERE p.activo = 1
    GROUP BY p.id_producto, p.codigo, p.nombre, p.stock_minimo
    HAVING COALESCE(
               SUM(CASE
                       WHEN l.fecha_vencimiento IS NULL
                            OR l.fecha_vencimiento >= CONVERT(date, GETDATE())
                       THEN l.stock_actual
                       ELSE 0
                   END), 0
           ) <= p.stock_minimo
    ORDER BY stock_disponible, p.nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Alertas_PorVencer
    @dias INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    IF @dias IS NULL OR @dias < 0 OR @dias > 3650
        THROW 51301, N'El número de días está fuera de rango', 1;

    SELECT p.codigo,
           p.nombre,
           l.numero_lote,
           l.fecha_vencimiento,
           l.stock_actual,
           CASE
               WHEN l.fecha_vencimiento < CONVERT(date, GETDATE()) THEN 'VENCIDO'
               ELSE 'PROXIMO'
           END AS estado
    FROM dbo.Lotes l
    JOIN dbo.Productos p ON p.id_producto = l.id_producto
    WHERE p.activo = 1
      AND l.stock_actual > 0
      AND l.fecha_vencimiento IS NOT NULL
      AND l.fecha_vencimiento <= DATEADD(day, @dias, CONVERT(date, GETDATE()))
    ORDER BY l.fecha_vencimiento;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Resumen
    @desde DATE = NULL,
    @hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        (SELECT COUNT(*) FROM dbo.Productos WHERE activo = 1) AS productos_activos,

        (SELECT COUNT(*)
         FROM (
             SELECT p.id_producto
             FROM dbo.Productos p
             LEFT JOIN dbo.Lotes l ON l.id_producto = p.id_producto
             WHERE p.activo = 1
             GROUP BY p.id_producto, p.stock_minimo
             HAVING COALESCE(
                        SUM(CASE
                                WHEN l.fecha_vencimiento IS NULL
                                     OR l.fecha_vencimiento >= CONVERT(date, GETDATE())
                                THEN l.stock_actual
                                ELSE 0
                            END), 0
                    ) <= p.stock_minimo
         ) x) AS productos_stock_bajo,

        (SELECT COUNT(*)
         FROM dbo.Lotes l
         JOIN dbo.Productos p ON p.id_producto = l.id_producto
         WHERE p.activo = 1
           AND l.stock_actual > 0
           AND l.fecha_vencimiento < CONVERT(date, GETDATE())) AS lotes_vencidos,

        (SELECT COUNT(*)
         FROM dbo.Lotes l
         JOIN dbo.Productos p ON p.id_producto = l.id_producto
         WHERE p.activo = 1
           AND l.stock_actual > 0
           AND l.fecha_vencimiento BETWEEN CONVERT(date, GETDATE())
                                        AND DATEADD(day, 30, CONVERT(date, GETDATE()))
        ) AS lotes_proximos_vencer,

        (SELECT COALESCE(
                    SUM(CAST(l.stock_actual AS DECIMAL(19,2)) * p.precio_unitario), 0
                )
         FROM dbo.Lotes l
         JOIN dbo.Productos p ON p.id_producto = l.id_producto
         WHERE p.activo = 1) AS valor_referencial_inventario,

        (SELECT COUNT(*)
         FROM dbo.Movimientos m
         WHERE (@desde IS NULL OR m.fecha_movimiento >= @desde)
           AND (@hasta IS NULL
                OR m.fecha_movimiento < DATEADD(day, 1, CAST(@hasta AS DATETIME2)))
        ) AS movimientos_periodo;
END;
GO

PRINT N'10_sp_alertas_dashboard.sql ejecutado.';
GO


-- ============================================================================
-- 11_sp_reportes.sql
-- ============================================================================

-- SIGIH | 11 - Reportes (solo lectura)
-- Convención: sp_Reportes_<Accion>

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reportes_MayoresSalidas
    @desde DATE,
    @hasta DATE,
    @top   INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @desde IS NULL OR @hasta IS NULL OR @desde > @hasta
        THROW 51302, N'Rango de fechas inválido', 1;

    IF @top IS NULL OR @top <= 0
        THROW 51701, N'El límite del reporte debe ser mayor que cero', 1;

    SELECT TOP (@top)
           p.id_producto,
           p.codigo,
           p.nombre,
           SUM(CAST(m.cantidad AS BIGINT)) AS total_salidas
    FROM dbo.Movimientos m
    JOIN dbo.Productos p ON p.id_producto = m.id_producto
    WHERE m.tipo_movimiento = 'SALIDA'
      AND m.fecha_movimiento >= @desde
      AND m.fecha_movimiento < DATEADD(day, 1, CAST(@hasta AS DATETIME2))
    GROUP BY p.id_producto, p.codigo, p.nombre
    ORDER BY total_salidas DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reportes_ConsumoPorArea
    @desde DATE,
    @hasta DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @desde IS NULL OR @hasta IS NULL OR @desde > @hasta
        THROW 51302, N'Rango de fechas inválido', 1;

    SELECT a.id_area,
           a.nombre AS area,
           COUNT(*) AS total_movimientos,
           SUM(CAST(m.cantidad AS BIGINT)) AS total_unidades
    FROM dbo.Movimientos m
    JOIN dbo.AreasHospitalarias a ON a.id_area = m.id_area
    WHERE m.tipo_movimiento = 'SALIDA'
      AND m.fecha_movimiento >= @desde
      AND m.fecha_movimiento < DATEADD(day, 1, CAST(@hasta AS DATETIME2))
    GROUP BY a.id_area, a.nombre
    ORDER BY total_unidades DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reportes_StockValorizado
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.id_producto,
           p.codigo,
           p.nombre,
           c.nombre AS categoria,
           COALESCE(SUM(l.stock_actual), 0) AS stock_total,
           p.precio_unitario,
           CAST(COALESCE(SUM(l.stock_actual), 0) AS DECIMAL(19,2))
               * p.precio_unitario AS valor_total
    FROM dbo.Productos p
    JOIN dbo.Categorias c ON c.id_categoria = p.id_categoria
    LEFT JOIN dbo.Lotes l ON l.id_producto = p.id_producto
    WHERE p.activo = 1
    GROUP BY p.id_producto, p.codigo, p.nombre, c.nombre, p.precio_unitario
    ORDER BY valor_total DESC;
END;
GO

PRINT N'11_sp_reportes.sql ejecutado.';
GO


-- ============================================================================
-- 12_sp_auditoria.sql
-- ============================================================================

-- SIGIH | 12 - Auditoría
-- Solo registro en esta fase; el listado se difiere a la siguiente.
-- El registro es best-effort: nunca debe tumbar la operación principal.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auditoria_Registrar
    @id_usuario INT = NULL,
    @accion     NVARCHAR(50),
    @modulo     NVARCHAR(50),
    @id_registro NVARCHAR(50) = NULL,
    @detalle    NVARCHAR(500) = NULL,
    @ip         NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NULLIF(TRIM(@accion), N'') IS NULL
           OR NULLIF(TRIM(@modulo), N'') IS NULL
            RETURN;

        IF @id_usuario IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario
           )
            SET @id_usuario = NULL;

        INSERT dbo.Auditoria
        (
            id_usuario, accion, modulo, id_registro, detalle, ip
        )
        VALUES
        (
            @id_usuario,
            LEFT(TRIM(@accion), 50),
            LEFT(TRIM(@modulo), 50),
            LEFT(@id_registro, 50),
            LEFT(@detalle, 500),
            LEFT(@ip, 45)
        );
    END TRY
    BEGIN CATCH
        -- Best-effort: se ignoran los fallos de auditoría.
    END CATCH
END;
GO

PRINT N'12_sp_auditoria.sql ejecutado.';
GO


-- ============================================================================
-- 13_wrappers_legacy.sql
-- ============================================================================

-- SIGIH | 13 - Wrappers de compatibilidad con los nombres legacy
-- Mantienen las firmas antiguas mientras el backend termina la migración.
-- No contienen lógica propia: delegan en los SP canónicos.
-- Se pueden retirar cuando ningún cliente llame a los nombres legacy.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Crear
    @nombre NVARCHAR(100),
    @email NVARCHAR(150),
    @password_hash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Usuarios_Crear
        @nombre = @nombre,
        @email = @email,
        @password_hash = @password_hash,
        @id_rol = NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ObtenerPorEmail
    @email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_usuario, nombre, email, password_hash, activo
    FROM dbo.Usuarios
    WHERE email = @email;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Crear
    @nombre NVARCHAR(100),
    @descripcion NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Categorias_Crear
        @nombre = @nombre,
        @descripcion = @descripcion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Listar
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Categorias_Listar @solo_activos = NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Obtener
    @id_categoria INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Categorias_Obtener @id_categoria = @id_categoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Actualizar
    @id_categoria INT,
    @nombre NVARCHAR(100),
    @descripcion NVARCHAR(255) = NULL,
    @activo BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Categorias_Actualizar
        @id_categoria = @id_categoria,
        @nombre = @nombre,
        @descripcion = @descripcion,
        @activo = @activo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Desactivar
    @id_categoria INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Categorias_Desactivar @id_categoria = @id_categoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_Crear
    @id_categoria INT,
    @codigo NVARCHAR(30),
    @nombre NVARCHAR(150),
    @descripcion NVARCHAR(500) = NULL,
    @unidad_medida NVARCHAR(30),
    @precio_unitario DECIMAL(12,2),
    @stock_minimo INT = 0,
    @maneja_lotes BIT = 0,
    @requiere_vencimiento BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Productos_Crear
        @id_categoria = @id_categoria,
        @codigo = @codigo,
        @nombre = @nombre,
        @descripcion = @descripcion,
        @unidad_medida = @unidad_medida,
        @precio_unitario = @precio_unitario,
        @stock_minimo = @stock_minimo,
        @maneja_lotes = @maneja_lotes,
        @requiere_vencimiento = @requiere_vencimiento;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_Listar
    @busqueda NVARCHAR(150) = NULL,
    @id_categoria INT = NULL,
    @solo_activos BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Productos_Listar
        @busqueda = @busqueda,
        @id_categoria = @id_categoria,
        @solo_activos = @solo_activos;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_Obtener
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Productos_Obtener @id_producto = @id_producto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_Actualizar
    @id_producto INT,
    @id_categoria INT,
    @codigo NVARCHAR(30),
    @nombre NVARCHAR(150),
    @descripcion NVARCHAR(500) = NULL,
    @unidad_medida NVARCHAR(30),
    @precio_unitario DECIMAL(12,2),
    @stock_minimo INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Productos_Actualizar
        @id_producto = @id_producto,
        @id_categoria = @id_categoria,
        @codigo = @codigo,
        @nombre = @nombre,
        @descripcion = @descripcion,
        @unidad_medida = @unidad_medida,
        @precio_unitario = @precio_unitario,
        @stock_minimo = @stock_minimo,
        @activo = NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_Desactivar
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Productos_Desactivar @id_producto = @id_producto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Lote_ListarPorProducto
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Lotes_ListarPorProducto @id_producto = @id_producto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Entrada_Registrar
    @id_producto INT,
    @id_usuario INT,
    @cantidad INT,
    @motivo NVARCHAR(200),
    @numero_lote NVARCHAR(50) = NULL,
    @fecha_vencimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Movimientos_RegistrarEntrada
        @id_producto = @id_producto,
        @id_usuario = @id_usuario,
        @cantidad = @cantidad,
        @motivo = @motivo,
        @numero_lote = @numero_lote,
        @fecha_vencimiento = @fecha_vencimiento;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Salida_Registrar
    @id_producto INT,
    @id_lote INT,
    @id_usuario INT,
    @id_area INT,
    @cantidad INT,
    @motivo NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Movimientos_RegistrarSalida
        @id_producto = @id_producto,
        @id_lote = @id_lote,
        @id_usuario = @id_usuario,
        @id_area = @id_area,
        @cantidad = @cantidad,
        @motivo = @motivo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimiento_Listar
    @id_producto INT = NULL,
    @tipo_movimiento VARCHAR(10) = NULL,
    @id_area INT = NULL,
    @desde DATE = NULL,
    @hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Movimientos_Listar
        @id_producto = @id_producto,
        @tipo_movimiento = @tipo_movimiento,
        @id_area = @id_area,
        @desde = @desde,
        @hasta = @hasta;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_StockBajo
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Alertas_StockBajo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Lote_Vencimientos
    @dias INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Alertas_PorVencer @dias = @dias;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Producto_MayoresSalidas
    @desde DATE,
    @hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Reportes_MayoresSalidas
        @desde = @desde,
        @hasta = @hasta,
        @top = 2147483647;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Area_Listar
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_Areas_Listar @solo_activos = NULL;
END;
GO

PRINT N'13_wrappers_legacy.sql ejecutado.';
GO


-- ============================================================================
-- 14_seed_catalogos.sql
-- ============================================================================

-- SIGIH | 14 - Catálogos iniciales
-- Idempotente: no duplica categorías ni áreas existentes.

USE SIGIH;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Medicamentos')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Medicamentos', N'Medicamentos de uso hospitalario');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material médico')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material médico', N'Insumos médicos');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material de laboratorio')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material de laboratorio', N'Insumos de laboratorio');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Limpieza hospitalaria')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Limpieza hospitalaria', N'Productos de limpieza');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Emergencia')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Emergencia');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Hospitalización')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Hospitalización');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Consultorios externos')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Consultorios externos');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Laboratorio')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Laboratorio');

PRINT N'14_seed_catalogos.sql ejecutado.';
GO


-- ============================================================================
-- 15_seed_rbac.sql
-- ============================================================================

-- SIGIH | 15 - RBAC: roles, permisos y asignaciones iniciales
-- Idempotente. Los códigos de permiso son modulo:accion.

USE SIGIH;
GO

-- Roles base
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ADMINISTRADOR')
    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (N'ADMINISTRADOR', N'Acceso total al sistema', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ALMACEN')
    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (N'ALMACEN', N'Gestión de inventario y movimientos', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'CONSULTA')
    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (N'CONSULTA', N'Acceso de solo lectura', 1);

-- Autocorregir descripciones si el rol ya existía con otro texto.
UPDATE dbo.Roles
SET descripcion = CASE nombre
        WHEN N'ADMINISTRADOR' THEN N'Acceso total al sistema'
        WHEN N'ALMACEN'       THEN N'Gestión de inventario y movimientos'
        WHEN N'CONSULTA'      THEN N'Acceso de solo lectura'
        ELSE descripcion
    END
WHERE nombre IN (N'ADMINISTRADOR', N'ALMACEN', N'CONSULTA');

-- Permisos
;WITH nuevos AS (
    SELECT *
    FROM (VALUES
        (N'categorias:leer',      N'categorias', N'Consultar categorías'),
        (N'categorias:escribir',  N'categorias', N'Crear, editar y desactivar categorías'),
        (N'productos:leer',       N'productos',  N'Consultar productos'),
        (N'productos:escribir',   N'productos',  N'Crear, editar y desactivar productos'),
        (N'lotes:leer',           N'lotes',      N'Consultar lotes'),
        (N'movimientos:leer',     N'movimientos',N'Consultar movimientos'),
        (N'movimientos:entrada',  N'movimientos',N'Registrar entradas'),
        (N'movimientos:salida',   N'movimientos',N'Registrar salidas'),
        (N'areas:leer',           N'areas',      N'Consultar áreas'),
        (N'areas:escribir',       N'areas',      N'Crear, editar y desactivar áreas'),
        (N'alertas:leer',         N'alertas',    N'Consultar alertas de inventario'),
        (N'dashboard:leer',       N'dashboard',  N'Consultar el dashboard'),
        (N'reportes:leer',        N'reportes',   N'Consultar reportes'),
        (N'usuarios:gestionar',   N'usuarios',   N'Gestionar usuarios'),
        (N'roles:gestionar',      N'roles',      N'Gestionar roles y permisos'),
        (N'auditoria:leer',       N'auditoria',  N'Consultar auditoría')
    ) v(codigo, modulo, descripcion)
)
INSERT dbo.Permisos (codigo, modulo, descripcion)
SELECT n.codigo, n.modulo, n.descripcion
FROM nuevos n
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Permisos p WHERE p.codigo = n.codigo
);

-- Autocorregir módulo/descripción de permisos ya existentes.
;WITH nuevos AS (
    SELECT *
    FROM (VALUES
        (N'categorias:leer',      N'categorias', N'Consultar categorías'),
        (N'categorias:escribir',  N'categorias', N'Crear, editar y desactivar categorías'),
        (N'productos:leer',       N'productos',  N'Consultar productos'),
        (N'productos:escribir',   N'productos',  N'Crear, editar y desactivar productos'),
        (N'lotes:leer',           N'lotes',      N'Consultar lotes'),
        (N'movimientos:leer',     N'movimientos',N'Consultar movimientos'),
        (N'movimientos:entrada',  N'movimientos',N'Registrar entradas'),
        (N'movimientos:salida',   N'movimientos',N'Registrar salidas'),
        (N'areas:leer',           N'areas',      N'Consultar áreas'),
        (N'areas:escribir',       N'areas',      N'Crear, editar y desactivar áreas'),
        (N'alertas:leer',         N'alertas',    N'Consultar alertas de inventario'),
        (N'dashboard:leer',       N'dashboard',  N'Consultar el dashboard'),
        (N'reportes:leer',        N'reportes',   N'Consultar reportes'),
        (N'usuarios:gestionar',   N'usuarios',   N'Gestionar usuarios'),
        (N'roles:gestionar',      N'roles',      N'Gestionar roles y permisos'),
        (N'auditoria:leer',       N'auditoria',  N'Consultar auditoría')
    ) v(codigo, modulo, descripcion)
)
UPDATE p
SET modulo = n.modulo,
    descripcion = n.descripcion
FROM dbo.Permisos p
JOIN nuevos n ON n.codigo = p.codigo;

-- ADMINISTRADOR: todos los permisos
INSERT dbo.RolesPermisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM dbo.Roles r
CROSS JOIN dbo.Permisos p
WHERE r.nombre = N'ADMINISTRADOR'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolesPermisos rp
      WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso
  );

-- ALMACEN: inventario operativo
INSERT dbo.RolesPermisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM dbo.Roles r
JOIN dbo.Permisos p ON p.codigo IN (
    N'categorias:leer',
    N'productos:leer', N'productos:escribir',
    N'lotes:leer',
    N'movimientos:leer', N'movimientos:entrada', N'movimientos:salida',
    N'areas:leer',
    N'alertas:leer',
    N'dashboard:leer',
    N'reportes:leer'
)
WHERE r.nombre = N'ALMACEN'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolesPermisos rp
      WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso
  );

-- CONSULTA: solo lectura
INSERT dbo.RolesPermisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM dbo.Roles r
JOIN dbo.Permisos p ON p.codigo IN (
    N'categorias:leer',
    N'productos:leer',
    N'lotes:leer',
    N'movimientos:leer',
    N'areas:leer',
    N'alertas:leer',
    N'dashboard:leer',
    N'reportes:leer'
)
WHERE r.nombre = N'CONSULTA'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolesPermisos rp
      WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso
  );

-- Asignar ADMINISTRADOR al administrador ya existente (si lo hay).
INSERT dbo.UsuariosRoles (id_usuario, id_rol)
SELECT u.id_usuario, r.id_rol
FROM dbo.Usuarios u
JOIN dbo.Roles r ON r.nombre = N'ADMINISTRADOR'
WHERE u.email = N'admin.desarrollo@sigih.test'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.UsuariosRoles ur
      WHERE ur.id_usuario = u.id_usuario AND ur.id_rol = r.id_rol
  );

PRINT N'15_seed_rbac.sql ejecutado.';
GO


-- ============================================================================
-- 16_admin_inicial.sql
-- ============================================================================

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


-- ============================================================================
-- 17_permisos_app.sql
-- Login y usuario de aplicación sigih_app (solo puede ejecutar SPs de dbo).
-- Adaptado de la versión con variable sqlcmd: aquí la contraseña se edita
-- directamente en la línea siguiente.
-- ============================================================================

USE master;
GO

DECLARE @password NVARCHAR(128) = N'Sigih.App.2026!';

IF @password = N''
    THROW 51801, N'Defina una contraseña para sigih_app en la variable @password.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.server_principals WHERE name = N'sigih_app'
)
BEGIN
    DECLARE @crear NVARCHAR(MAX) =
        N'CREATE LOGIN [sigih_app] WITH PASSWORD = N'''
        + REPLACE(@password, N'''', N'''''')
        + N''', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
    EXEC sp_executesql @crear;
END
ELSE
BEGIN
    DECLARE @alterar NVARCHAR(MAX) =
        N'ALTER LOGIN [sigih_app] WITH PASSWORD = N'''
        + REPLACE(@password, N'''', N'''''')
        + N''', CHECK_POLICY = OFF;';
    EXEC sp_executesql @alterar;
END;
GO

USE SIGIH;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = N'sigih_app'
)
BEGIN
    CREATE USER [sigih_app] FOR LOGIN [sigih_app] WITH DEFAULT_SCHEMA = dbo;
END;
GO

GRANT CONNECT TO [sigih_app];
GO

-- Solo procedimientos almacenados.
GRANT EXECUTE ON SCHEMA::dbo TO [sigih_app];
GO

-- Sin acceso directo a tablas ni vistas.
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [sigih_app];
GO

PRINT N'17_permisos_app.sql ejecutado.';
GO


-- ============================================================================
-- 18_seed_demo.sql
-- ============================================================================

-- SIGIH | 18 - Datos de demostración
-- ----------------------------------------------------------------------------
-- Carga un catálogo realista para que el sistema no arranque vacío:
--   5 categorías · 8 áreas · 21 productos · 43 movimientos
--
-- Reglas que respeta:
--   * El stock SOLO se mueve con sp_Movimientos_RegistrarEntrada/Salida,
--     de modo que Lotes y Movimientos quedan consistentes y se cumplen
--     CK_Mov_Area y CK_Mov_Cambio.
--   * Es idempotente: los productos se guardan por `codigo`, las entradas y
--     salidas por `motivo`. Ejecutarlo dos veces no duplica nada.
--   * No borra ni modifica datos ajenos a la demostración.
--   * Deja 3 productos en stock bajo, 2 lotes por vencer y 1 lote vencido
--     para que Alertas y Dashboard tengan contenido.
-- ----------------------------------------------------------------------------

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @id_admin       INT,
        @id_almacen     INT,
        @id_producto    INT,
        @id_lote        INT,
        @id_area        INT,
        @id_usuario     INT,
        @id_movimiento  INT,
        @cantidad       INT,
        @motivo         NVARCHAR(200),
        @numero_lote    NVARCHAR(50),
        @vence          DATE,
        @dias           INT;

DECLARE @res TABLE
(
    id_movimiento  INT,
    id_lote        INT,
    stock_anterior INT,
    stock_posterior INT
);

-- ============================================================================
-- 0. Usuarios de la demostración
-- ============================================================================

SET @id_admin = (SELECT id_usuario FROM dbo.Usuarios WHERE email = N'admin.desarrollo@sigih.test');

IF @id_admin IS NULL
    THROW 51901, N'No existe el administrador inicial. Ejecute antes 16_admin_inicial.sql.', 1;

-- Usuario de almacén con la misma contraseña de desarrollo (Admin.2026!).
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE email = N'almacen.demo@sigih.test')
BEGIN
    INSERT dbo.Usuarios (nombre, email, password_hash, activo)
    SELECT N'Jefe de Almacén', N'almacen.demo@sigih.test', password_hash, 1
    FROM dbo.Usuarios
    WHERE email = N'admin.desarrollo@sigih.test';
END;

SET @id_almacen = (SELECT id_usuario FROM dbo.Usuarios WHERE email = N'almacen.demo@sigih.test');

IF @id_almacen IS NOT NULL
   AND EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ALMACEN')
BEGIN
    INSERT dbo.UsuariosRoles (id_usuario, id_rol)
    SELECT @id_almacen, r.id_rol
    FROM dbo.Roles r
    WHERE r.nombre = N'ALMACEN'
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.UsuariosRoles ur
          WHERE ur.id_usuario = @id_almacen AND ur.id_rol = r.id_rol
      );
END;

-- ============================================================================
-- 1. Categorías y áreas
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Medicamentos')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Medicamentos', N'Medicamentos de uso hospitalario');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material médico')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material médico', N'Insumos y material de atención médica');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material de laboratorio')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material de laboratorio', N'Insumos y reactivos de laboratorio clínico');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Limpieza hospitalaria')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Limpieza hospitalaria', N'Productos de desinfección y limpieza');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Equipos y dispositivos médicos')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Equipos y dispositivos médicos', N'Equipos biomédicos y dispositivos de medición');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Emergencia')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Emergencia');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Hospitalización')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Hospitalización');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Consultorios externos')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Consultorios externos');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Laboratorio')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Laboratorio');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Quirófano')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Quirófano');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'UCI')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'UCI');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Pediatría')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Pediatría');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Farmacia')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Farmacia');

-- ============================================================================
-- 2. Productos
-- ============================================================================

DECLARE @productos TABLE
(
    codigo               NVARCHAR(30)  NOT NULL,
    nombre               NVARCHAR(150) NOT NULL,
    categoria            NVARCHAR(100) NOT NULL,
    descripcion          NVARCHAR(500) NULL,
    unidad_medida        NVARCHAR(30)  NOT NULL,
    precio_unitario      DECIMAL(12,2) NOT NULL,
    stock_minimo         INT           NOT NULL,
    maneja_lotes         BIT           NOT NULL,
    requiere_vencimiento BIT           NOT NULL
);

INSERT @productos
    (codigo, nombre, categoria, descripcion, unidad_medida, precio_unitario,
     stock_minimo, maneja_lotes, requiere_vencimiento)
VALUES
    -- Medicamentos
    (N'MED-PAR-500', N'Paracetamol 500 mg', N'Medicamentos',
     N'Analgésico y antipirético de primera línea', N'tableta', 0.15, 800, 1, 1),
    (N'MED-IBU-400', N'Ibuprofeno 400 mg', N'Medicamentos',
     N'Antiinflamatorio no esteroideo', N'tableta', 0.20, 600, 1, 1),
    (N'MED-AMO-500', N'Amoxicilina 500 mg', N'Medicamentos',
     N'Antibiótico de amplio espectro', N'cápsula', 0.45, 400, 1, 1),
    (N'MED-OME-20', N'Omeprazol 20 mg', N'Medicamentos',
     N'Inhibidor de la bomba de protones', N'cápsula', 0.30, 300, 1, 1),
    (N'MED-SSF-09', N'Solución fisiológica 0.9% 500 ml', N'Medicamentos',
     N'Solución salina isotónica para infusión', N'frasco', 3.80, 150, 1, 1),
    (N'MED-DEX-05', N'Dextrosa 5% 500 ml', N'Medicamentos',
     N'Solución glucosada para infusión', N'frasco', 4.20, 120, 1, 1),
    (N'MED-ADR-01', N'Adrenalina 1 mg/ml', N'Medicamentos',
     N'Vasopresor para emergencias', N'ampolla', 5.50, 60, 1, 1),

    -- Material médico
    (N'MAT-GUA-NIT-M', N'Guantes de nitrilo M', N'Material médico',
     N'Caja con 100 guantes de examen', N'caja', 24.90, 40, 1, 1),
    (N'MAT-JER-10', N'Jeringa 10 ml', N'Material médico',
     N'Jeringa desechable con aguja', N'unidad', 0.35, 500, 1, 0),
    (N'MAT-GAS-10', N'Gasa estéril 10x10', N'Material médico',
     N'Paquete con 10 gasas estériles', N'paquete', 1.10, 300, 1, 1),
    (N'MAT-AGU-21', N'Aguja hipodérmica 21G', N'Material médico',
     N'Aguja desechable para inyección', N'unidad', 0.12, 800, 1, 0),
    (N'MAT-CAT-20', N'Catéter venoso 20G', N'Material médico',
     N'Catéter periférico para canalización', N'unidad', 1.85, 200, 1, 0),
    (N'MAT-SUT-30', N'Sutura nylon 3-0', N'Material médico',
     N'Hilo de sutura no absorbible', N'unidad', 9.75, 50, 1, 1),

    -- Material de laboratorio
    (N'LAB-TUB-EDTA', N'Tubo EDTA tapa lila', N'Material de laboratorio',
     N'Tubo para hemograma con anticoagulante', N'unidad', 0.55, 400, 1, 1),
    (N'LAB-TUB-SER', N'Tubo seco tapa roja', N'Material de laboratorio',
     N'Tubo para química sanguínea sin anticoagulante', N'unidad', 0.50, 400, 1, 1),
    (N'LAB-REA-GLU', N'Reactivo glucosa oxidasa 500 ml', N'Material de laboratorio',
     N'Reactivo para determinación de glucosa', N'frasco', 38.00, 12, 1, 1),
    (N'LAB-PAP-FIL', N'Papel filtro cualitativo caja x100', N'Material de laboratorio',
     N'Papel filtro para laboratorio', N'caja', 12.50, 15, 0, 0),

    -- Limpieza hospitalaria
    (N'LIM-HIP-05', N'Hipoclorito de sodio 5% 1 L', N'Limpieza hospitalaria',
     N'Desinfectante de superficies', N'galón', 6.40, 60, 0, 0),
    (N'LIM-ALC-70', N'Alcohol etílico 70% 1 L', N'Limpieza hospitalaria',
     N'Antiséptico y desinfectante', N'galón', 7.20, 60, 0, 0),

    -- Equipos y dispositivos médicos
    (N'EQP-TEN-DIG', N'Tensiómetro digital de brazo', N'Equipos y dispositivos médicos',
     N'Monitor de presión arterial automático', N'unidad', 185.00, 3, 0, 0),
    (N'EQP-TER-INF', N'Termómetro infrarrojo', N'Equipos y dispositivos médicos',
     N'Termómetro sin contacto para triaje', N'unidad', 95.00, 4, 0, 0);

INSERT dbo.Productos
    (id_categoria, codigo, nombre, descripcion, unidad_medida,
     precio_unitario, stock_minimo, maneja_lotes, requiere_vencimiento, activo)
SELECT c.id_categoria,
       p.codigo,
       p.nombre,
       p.descripcion,
       p.unidad_medida,
       p.precio_unitario,
       p.stock_minimo,
       p.maneja_lotes,
       p.requiere_vencimiento,
       1
FROM @productos p
JOIN dbo.Categorias c ON c.nombre = p.categoria AND c.activo = 1
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Productos x WHERE x.codigo = p.codigo
);

IF EXISTS (
    SELECT 1
    FROM @productos p
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Productos x WHERE x.codigo = p.codigo
    )
)
    THROW 51902, N'No se pudieron crear todos los productos de demostración. Verifique que las categorías existan y estén activas.', 1;

-- ============================================================================
-- 3. Entradas de inventario (crean los lotes)
-- ============================================================================

DECLARE @entradas TABLE
(
    codigo            NVARCHAR(30)  NOT NULL,
    cantidad          INT           NOT NULL,
    motivo            NVARCHAR(200) NOT NULL,
    numero_lote       NVARCHAR(50)  NULL,
    fecha_vencimiento DATE          NULL,
    dias              INT           NOT NULL
);

INSERT @entradas (codigo, cantidad, motivo, numero_lote, fecha_vencimiento, dias)
VALUES
    (N'MED-PAR-500', 1800, N'Compra inicial · lote PAR-2601', N'PAR-2601', DATEADD(day, 420, CONVERT(date, GETDATE())), -150),
    (N'MED-PAR-500',  400, N'Compra inicial · lote PAR-2512', N'PAR-2512', DATEADD(day,  25, CONVERT(date, GETDATE())),  -95),
    (N'MED-IBU-400', 1200, N'Compra inicial · lote IBU-2602', N'IBU-2602', DATEADD(day, 540, CONVERT(date, GETDATE())), -145),
    (N'MED-AMO-500',  300, N'Compra inicial · lote AMO-2601', N'AMO-2601', DATEADD(day, 300, CONVERT(date, GETDATE())), -140),
    (N'MED-OME-20',   800, N'Compra inicial · lote OME-2602', N'OME-2602', DATEADD(day, 480, CONVERT(date, GETDATE())), -135),
    (N'MED-SSF-09',   300, N'Compra inicial · lote SSF-2511', N'SSF-2511', DATEADD(day,  60, CONVERT(date, GETDATE())), -160),
    (N'MED-SSF-09',   200, N'Compra inicial · lote SSF-2604', N'SSF-2604', DATEADD(day, 240, CONVERT(date, GETDATE())), -120),
    (N'MED-DEX-05',   250, N'Compra inicial · lote DEX-2603', N'DEX-2603', DATEADD(day, 270, CONVERT(date, GETDATE())), -130),
    (N'MED-ADR-01',    40, N'Compra inicial · lote ADR-2601', N'ADR-2601', DATEADD(day, 330, CONVERT(date, GETDATE())), -125),
    (N'MAT-GUA-NIT-M', 80, N'Compra inicial · lote GUA-2602', N'GUA-2602', DATEADD(day, 720, CONVERT(date, GETDATE())), -120),
    (N'MAT-JER-10',  1200, N'Compra inicial · lote JER-2601', N'JER-2601', NULL, -115),
    (N'MAT-GAS-10',   400, N'Compra inicial · lote GAS-2601', N'GAS-2601', DATEADD(day,  20, CONVERT(date, GETDATE())), -110),
    (N'MAT-AGU-21',  2000, N'Compra inicial · lote AGU-2602', N'AGU-2602', NULL, -105),
    (N'MAT-CAT-20',   500, N'Compra inicial · lote CAT-2601', N'CAT-2601', NULL, -100),
    (N'MAT-SUT-30',   120, N'Compra inicial · lote SUT-2601', N'SUT-2601', DATEADD(day, 600, CONVERT(date, GETDATE())),  -95),
    (N'LAB-TUB-EDTA',1000, N'Compra inicial · lote EDTA-2602', N'EDTA-2602', DATEADD(day, 210, CONVERT(date, GETDATE())), -90),
    (N'LAB-TUB-SER', 1000, N'Compra inicial · lote SER-2602', N'SER-2602', DATEADD(day, 210, CONVERT(date, GETDATE())), -85),
    (N'LAB-REA-GLU',   10, N'Compra inicial · lote GLU-2601', N'GLU-2601', DATEADD(day, 150, CONVERT(date, GETDATE())), -80),
    (N'LAB-PAP-FIL',   30, N'Compra inicial · papel filtro', NULL, NULL, -75),
    (N'LIM-HIP-05',   120, N'Compra inicial · hipoclorito', NULL, NULL, -70),
    (N'LIM-ALC-70',   120, N'Compra inicial · alcohol 70%', NULL, NULL, -65),
    (N'EQP-TEN-DIG',    6, N'Compra inicial · tensiómetros', NULL, NULL, -60),
    (N'EQP-TER-INF',    8, N'Compra inicial · termómetros', NULL, NULL, -55);

DECLARE cur_entradas CURSOR LOCAL FAST_FORWARD FOR
    SELECT p.id_producto, e.cantidad, e.motivo, e.numero_lote,
           e.fecha_vencimiento, e.dias
    FROM @entradas e
    JOIN dbo.Productos p ON p.codigo = e.codigo
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Movimientos m
        WHERE m.id_producto = p.id_producto
          AND m.tipo_movimiento = 'ENTRADA'
          AND m.motivo = e.motivo
    )
    ORDER BY e.dias ASC, e.codigo ASC;

OPEN cur_entradas;

FETCH NEXT FROM cur_entradas
    INTO @id_producto, @cantidad, @motivo, @numero_lote, @vence, @dias;

WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @res;

    INSERT @res (id_movimiento, id_lote, stock_anterior, stock_posterior)
    EXEC dbo.sp_Movimientos_RegistrarEntrada
        @id_producto, @id_admin, @cantidad, @motivo, @numero_lote, @vence;

    SELECT @id_movimiento = id_movimiento, @id_lote = id_lote FROM @res;

    -- Reparte el historial en los últimos cuatro meses.
    UPDATE dbo.Movimientos
    SET fecha_movimiento = DATEADD(day, @dias, SYSDATETIME())
    WHERE id_movimiento = @id_movimiento;

    UPDATE dbo.Lotes
    SET fecha_registro = DATEADD(day, @dias, SYSDATETIME())
    WHERE id_lote = @id_lote;

    FETCH NEXT FROM cur_entradas
        INTO @id_producto, @cantidad, @motivo, @numero_lote, @vence, @dias;
END;

CLOSE cur_entradas;
DEALLOCATE cur_entradas;

-- ============================================================================
-- 4. Salidas de inventario (consumo por área)
-- ============================================================================

DECLARE @salidas TABLE
(
    codigo      NVARCHAR(30)  NOT NULL,
    numero_lote NVARCHAR(50)  NULL,
    area        NVARCHAR(100) NOT NULL,
    cantidad    INT           NOT NULL,
    motivo      NVARCHAR(200) NOT NULL,
    dias        INT           NOT NULL,
    email       NVARCHAR(150) NOT NULL
);

INSERT @salidas (codigo, numero_lote, area, cantidad, motivo, dias, email)
VALUES
    (N'MED-PAR-500', N'PAR-2601', N'Emergencia', 350,
     N'Consumo en Emergencia · paracetamol', -60, N'admin.desarrollo@sigih.test'),
    (N'MED-PAR-500', N'PAR-2601', N'Hospitalización', 250,
     N'Consumo en Hospitalización · paracetamol', -20, N'almacen.demo@sigih.test'),
    (N'MED-IBU-400', N'IBU-2602', N'Consultorios externos', 300,
     N'Dispensación en Consultorios externos · ibuprofeno', -50, N'admin.desarrollo@sigih.test'),
    (N'MED-AMO-500', N'AMO-2601', N'Emergencia', 50,
     N'Tratamiento en Emergencia · amoxicilina', -45, N'admin.desarrollo@sigih.test'),
    (N'MED-OME-20', N'OME-2602', N'Hospitalización', 180,
     N'Tratamiento en Hospitalización · omeprazol', -40, N'admin.desarrollo@sigih.test'),
    (N'MED-SSF-09', N'SSF-2511', N'Emergencia', 280,
     N'Reposición en Emergencia · solución fisiológica', -100, N'admin.desarrollo@sigih.test'),
    (N'MED-DEX-05', N'DEX-2603', N'UCI', 60,
     N'Infusión en UCI · dextrosa', -35, N'admin.desarrollo@sigih.test'),
    (N'MAT-GUA-NIT-M', N'GUA-2602', N'Quirófano', 20,
     N'Consumo en Quirófano · guantes', -30, N'almacen.demo@sigih.test'),
    (N'MAT-JER-10', N'JER-2601', N'Emergencia', 350,
     N'Consumo en Emergencia · jeringas', -25, N'admin.desarrollo@sigih.test'),
    (N'MAT-GAS-10', N'GAS-2601', N'Quirófano', 80,
     N'Curaciones en Quirófano · gasas', -22, N'almacen.demo@sigih.test'),
    (N'MAT-AGU-21', N'AGU-2602', N'Laboratorio', 600,
     N'Toma de muestras · agujas', -20, N'admin.desarrollo@sigih.test'),
    (N'MAT-CAT-20', N'CAT-2601', N'UCI', 120,
     N'Canalización en UCI · catéteres', -18, N'admin.desarrollo@sigih.test'),
    (N'MAT-SUT-30', N'SUT-2601', N'Quirófano', 30,
     N'Suturas en Quirófano', -16, N'almacen.demo@sigih.test'),
    (N'LAB-TUB-EDTA', N'EDTA-2602', N'Laboratorio', 250,
     N'Hemogramas · tubos EDTA', -14, N'admin.desarrollo@sigih.test'),
    (N'LAB-TUB-SER', N'SER-2602', N'Laboratorio', 240,
     N'Química sanguínea · tubos secos', -12, N'admin.desarrollo@sigih.test'),
    (N'LAB-PAP-FIL', NULL, N'Laboratorio', 8,
     N'Filtración de muestras · papel filtro', -10, N'admin.desarrollo@sigih.test'),
    (N'LIM-HIP-05', NULL, N'Hospitalización', 35,
     N'Desinfección en Hospitalización · hipoclorito', -8, N'almacen.demo@sigih.test'),
    (N'LIM-ALC-70', NULL, N'Quirófano', 40,
     N'Asepsia en Quirófano · alcohol', -6, N'almacen.demo@sigih.test'),
    (N'EQP-TEN-DIG', NULL, N'Consultorios externos', 2,
     N'Asignación en Consultorios externos · tensiómetro', -5, N'admin.desarrollo@sigih.test'),
    (N'EQP-TER-INF', NULL, N'Pediatría', 3,
     N'Asignación en Pediatría · termómetro', -3, N'almacen.demo@sigih.test');

DECLARE cur_salidas CURSOR LOCAL FAST_FORWARD FOR
    SELECT p.id_producto,
           l.id_lote,
           a.id_area,
           s.cantidad,
           s.motivo,
           s.dias,
           COALESCE(u.id_usuario, @id_admin)
    FROM @salidas s
    JOIN dbo.Productos p ON p.codigo = s.codigo
    JOIN dbo.Lotes l ON l.id_producto = p.id_producto
        AND (
            (s.numero_lote IS NULL AND l.numero_lote IS NULL)
            OR l.numero_lote = s.numero_lote
        )
    JOIN dbo.AreasHospitalarias a ON a.nombre = s.area AND a.activo = 1
    LEFT JOIN dbo.Usuarios u ON u.email = s.email AND u.activo = 1
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Movimientos m
        WHERE m.id_producto = p.id_producto
          AND m.tipo_movimiento = 'SALIDA'
          AND m.motivo = s.motivo
    )
    ORDER BY s.dias ASC, s.codigo ASC;

OPEN cur_salidas;

FETCH NEXT FROM cur_salidas
    INTO @id_producto, @id_lote, @id_area, @cantidad, @motivo, @dias, @id_usuario;

WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @res;

    INSERT @res (id_movimiento, stock_anterior, stock_posterior)
    EXEC dbo.sp_Movimientos_RegistrarSalida
        @id_producto, @id_lote, @id_usuario, @id_area, @cantidad, @motivo;

    SELECT @id_movimiento = id_movimiento FROM @res;

    UPDATE dbo.Movimientos
    SET fecha_movimiento = DATEADD(day, @dias, SYSDATETIME())
    WHERE id_movimiento = @id_movimiento;

    FETCH NEXT FROM cur_salidas
        INTO @id_producto, @id_lote, @id_area, @cantidad, @motivo, @dias, @id_usuario;
END;

CLOSE cur_salidas;
DEALLOCATE cur_salidas;

-- ============================================================================
-- 5. Lote vencido de demostración
-- ----------------------------------------------------------------------------
-- El SP no permite ingresar lotes vencidos, así que SSF-2511 se creó con
-- vencimiento futuro y aquí se retrocede para simular un lote ya vencido.
-- Se ejecuta después de las salidas para que estas sigan siendo válidas.
-- ============================================================================

UPDATE dbo.Lotes
SET fecha_vencimiento = DATEADD(day, -12, CONVERT(date, GETDATE()))
WHERE numero_lote = N'SSF-2511'
  AND id_producto = (
      SELECT id_producto FROM dbo.Productos WHERE codigo = N'MED-SSF-09'
  );

-- ============================================================================
-- 6. Resumen
-- ============================================================================

PRINT N'18_seed_demo.sql ejecutado.';

SELECT
    (SELECT COUNT(*)
     FROM dbo.Productos p
     JOIN @productos x ON x.codigo = p.codigo) AS productos_demo,
    (SELECT COUNT(*)
     FROM dbo.Lotes l
     JOIN dbo.Productos p ON p.id_producto = l.id_producto
     JOIN @productos x ON x.codigo = p.codigo) AS lotes_demo,
    (SELECT COUNT(*)
     FROM dbo.Movimientos m
     JOIN dbo.Productos p ON p.id_producto = m.id_producto
     JOIN @productos x ON x.codigo = p.codigo) AS movimientos_demo;
GO


-- ============================================================================
-- 99_verificar.sql
-- ============================================================================

-- SIGIH | 99 - Verificación de instalación
-- Solo lectura. Muestra el estado de tablas, SPs, RBAC y usuario de app.

USE SIGIH;
GO

PRINT N'--- Tablas base y RBAC ---';
SELECT t.name AS tabla
FROM sys.tables t
WHERE t.name IN (
    N'Usuarios', N'Categorias', N'Productos', N'Lotes',
    N'AreasHospitalarias', N'Movimientos',
    N'Roles', N'Permisos', N'RolesPermisos', N'UsuariosRoles', N'Auditoria'
)
ORDER BY t.name;

PRINT N'--- Stored procedures canónicos ---';
SELECT p.name AS procedimiento
FROM sys.procedures p
WHERE p.name IN (
    N'sp_Usuarios_ObtenerSesion', N'sp_Usuarios_Obtener', N'sp_Usuarios_Listar',
    N'sp_Usuarios_Crear', N'sp_Usuarios_Actualizar', N'sp_Usuarios_Desactivar',
    N'sp_Usuarios_CambiarPassword', N'sp_Usuarios_ListarRoles',
    N'sp_Usuarios_ListarPermisos', N'sp_Usuarios_AsignarRol', N'sp_Usuarios_QuitarRol',
    N'sp_Roles_Listar', N'sp_Roles_Obtener', N'sp_Roles_Crear',
    N'sp_Roles_Actualizar', N'sp_Roles_Desactivar', N'sp_Roles_ListarPermisos',
    N'sp_Roles_AsignarPermiso', N'sp_Roles_QuitarPermiso', N'sp_Roles_SincronizarPermisos',
    N'sp_Permisos_Listar', N'sp_Permisos_Obtener',
    N'sp_Categorias_Listar', N'sp_Categorias_Obtener', N'sp_Categorias_Crear',
    N'sp_Categorias_Actualizar', N'sp_Categorias_Desactivar',
    N'sp_Productos_Listar', N'sp_Productos_Obtener', N'sp_Productos_Crear',
    N'sp_Productos_Actualizar', N'sp_Productos_Desactivar', N'sp_Productos_Reactivar',
    N'sp_Lotes_ListarPorProducto', N'sp_Lotes_Obtener',
    N'sp_Movimientos_RegistrarEntrada', N'sp_Movimientos_RegistrarSalida',
    N'sp_Movimientos_Listar', N'sp_Movimientos_Obtener',
    N'sp_Areas_Listar', N'sp_Areas_Obtener', N'sp_Areas_Crear',
    N'sp_Areas_Actualizar', N'sp_Areas_Desactivar',
    N'sp_Alertas_StockBajo', N'sp_Alertas_PorVencer', N'sp_Dashboard_Resumen',
    N'sp_Reportes_MayoresSalidas', N'sp_Reportes_ConsumoPorArea',
    N'sp_Reportes_StockValorizado', N'sp_Auditoria_Registrar'
)
ORDER BY p.name;

PRINT N'--- RBAC ---';
SELECT r.nombre AS rol,
       COUNT(rp.id_permiso) AS permisos
FROM dbo.Roles r
LEFT JOIN dbo.RolesPermisos rp ON rp.id_rol = r.id_rol
GROUP BY r.nombre
ORDER BY r.nombre;

SELECT COUNT(*) AS total_permisos FROM dbo.Permisos;

PRINT N'--- Administrador inicial ---';
SELECT u.id_usuario, u.nombre, u.email, u.activo,
       STRING_AGG(r.nombre, N', ') AS roles
FROM dbo.Usuarios u
LEFT JOIN dbo.UsuariosRoles ur ON ur.id_usuario = u.id_usuario
LEFT JOIN dbo.Roles r ON r.id_rol = ur.id_rol
WHERE u.email = N'admin.desarrollo@sigih.test'
GROUP BY u.id_usuario, u.nombre, u.email, u.activo;

PRINT N'--- Usuario de aplicación ---';
SELECT dp.name AS usuario, dp.type_desc, dp.default_schema_name
FROM sys.database_principals dp
WHERE dp.name = N'sigih_app';

SELECT pr.state_desc, pr.permission_name, pr.class_desc
FROM sys.database_permissions pr
JOIN sys.database_principals dp ON dp.principal_id = pr.grantee_principal_id
WHERE dp.name = N'sigih_app'
ORDER BY pr.state_desc, pr.permission_name;

PRINT N'--- Conteos ---';
SELECT 'Categorias' AS entidad, COUNT(*) AS filas FROM dbo.Categorias
UNION ALL SELECT 'Areas', COUNT(*) FROM dbo.AreasHospitalarias
UNION ALL SELECT 'Productos', COUNT(*) FROM dbo.Productos
UNION ALL SELECT 'Lotes', COUNT(*) FROM dbo.Lotes
UNION ALL SELECT 'Movimientos', COUNT(*) FROM dbo.Movimientos
UNION ALL SELECT 'Usuarios', COUNT(*) FROM dbo.Usuarios;

PRINT N'--- Datos de demostración ---';
SELECT COUNT(DISTINCT p.id_producto) AS productos_activos,
       COALESCE(SUM(l.stock_actual), 0) AS unidades_en_stock
FROM dbo.Productos p
LEFT JOIN dbo.Lotes l ON l.id_producto = p.id_producto
WHERE p.activo = 1;

SELECT
    (SELECT COUNT(*)
     FROM dbo.Lotes l
     JOIN dbo.Productos p ON p.id_producto = l.id_producto
     WHERE p.activo = 1
       AND l.stock_actual > 0
       AND l.fecha_vencimiento < CONVERT(date, GETDATE())) AS lotes_vencidos,
    (SELECT COUNT(*)
     FROM dbo.Lotes l
     JOIN dbo.Productos p ON p.id_producto = l.id_producto
     WHERE p.activo = 1
       AND l.stock_actual > 0
       AND l.fecha_vencimiento BETWEEN CONVERT(date, GETDATE())
                                    AND DATEADD(day, 30, CONVERT(date, GETDATE()))) AS lotes_por_vencer,
    (SELECT COUNT(*)
     FROM dbo.Productos p
     WHERE p.activo = 1
       AND COALESCE((
               SELECT SUM(CASE
                              WHEN l.fecha_vencimiento IS NULL
                                   OR l.fecha_vencimiento >= CONVERT(date, GETDATE())
                              THEN l.stock_actual
                              ELSE 0
                          END)
               FROM dbo.Lotes l
               WHERE l.id_producto = p.id_producto
           ), 0) <= p.stock_minimo) AS productos_stock_bajo;

EXEC dbo.sp_Dashboard_Resumen;
GO

-- ============================================================================
-- FIN DE LA INSTALACIÓN
-- ============================================================================

PRINT N'';
PRINT N'============================================================';
PRINT N'INSTALACIÓN SIGIH FINALIZADA';
PRINT N'Si no aparecieron errores, la base SIGIH está lista.';
PRINT N'Recuerde que backend/.env debe usar DB_PASSWORD igual a la';
PRINT N'contraseña definida para sigih_app en este archivo.';
PRINT N'============================================================';
GO
