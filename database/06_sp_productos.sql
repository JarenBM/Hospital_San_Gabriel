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
