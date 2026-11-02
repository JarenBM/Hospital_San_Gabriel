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
