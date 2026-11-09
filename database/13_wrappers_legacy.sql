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
