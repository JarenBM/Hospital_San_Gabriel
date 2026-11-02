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
