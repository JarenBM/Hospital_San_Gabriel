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
               WHEN fecha_vencimiento <= CONVERT(date, GETDATE()) THEN 1
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
               WHEN fecha_vencimiento <= CONVERT(date, GETDATE()) THEN 1
               ELSE 0
           END AS vencido
    FROM dbo.Lotes
    WHERE id_lote = @id_lote;
END;
GO

PRINT N'07_sp_lotes.sql ejecutado.';
GO
