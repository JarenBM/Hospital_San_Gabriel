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
