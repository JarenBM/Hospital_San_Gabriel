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
        id_area      INT NULL
            CONSTRAINT FK_Auditoria_Areas REFERENCES dbo.AreasHospitalarias(id_area),
        detalle      NVARCHAR(500) NULL,
        ip           NVARCHAR(45) NULL,
        fecha        DATETIME2 NOT NULL
            CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME())
    );
END;
GO

-- Migración idempotente para instalaciones previas sin id_area.
IF COL_LENGTH(N'dbo.Auditoria', N'id_area') IS NULL
BEGIN
    ALTER TABLE dbo.Auditoria ADD id_area INT NULL
        CONSTRAINT FK_Auditoria_Areas REFERENCES dbo.AreasHospitalarias(id_area);
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
