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
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.AreasHospitalarias WHERE id_area = @id_area
    )
        THROW 51503, N'Área no encontrada', 1;

    -- El área conserva la trazabilidad de sus consumos: no se desactiva
    -- mientras existan movimientos que la referencien.
    IF EXISTS (
        SELECT 1 FROM dbo.Movimientos WHERE id_area = @id_area
    )
        THROW 51504, N'El área tiene movimientos registrados y no se puede desactivar', 1;

    UPDATE dbo.AreasHospitalarias SET activo = 0 WHERE id_area = @id_area;
END;
GO

PRINT N'09_sp_areas.sql ejecutado.';
GO
