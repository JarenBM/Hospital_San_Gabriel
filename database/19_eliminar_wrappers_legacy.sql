-- SIGIH | 19 - Eliminación de wrappers de compatibilidad legacy
-- La migración al catálogo canónico ya está completa: el backend solo
-- ejecuta los SP de sp_Usuarios_*, sp_Categorias_*, sp_Productos_*,
-- sp_Lotes_*, sp_Movimientos_* y sp_Areas_*. Los siguientes nombres
-- antiguos eran alias sin lógica propia y ya no los usa ningún cliente.
-- También se retira sp_Productos_Reactivar: no existe reactivación de
-- productos y ningún endpoint lo exponía.
--
-- Es idempotente: DROP PROCEDURE IF EXISTS no falla si ya no existen.

USE SIGIH;
GO

DROP PROCEDURE IF EXISTS dbo.sp_Usuario_Crear;
DROP PROCEDURE IF EXISTS dbo.sp_Usuario_ObtenerPorEmail;
DROP PROCEDURE IF EXISTS dbo.sp_Categoria_Crear;
DROP PROCEDURE IF EXISTS dbo.sp_Categoria_Listar;
DROP PROCEDURE IF EXISTS dbo.sp_Categoria_Obtener;
DROP PROCEDURE IF EXISTS dbo.sp_Categoria_Actualizar;
DROP PROCEDURE IF EXISTS dbo.sp_Categoria_Desactivar;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_Crear;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_Listar;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_Obtener;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_Actualizar;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_Desactivar;
DROP PROCEDURE IF EXISTS dbo.sp_Lote_ListarPorProducto;
DROP PROCEDURE IF EXISTS dbo.sp_Entrada_Registrar;
DROP PROCEDURE IF EXISTS dbo.sp_Salida_Registrar;
DROP PROCEDURE IF EXISTS dbo.sp_Movimiento_Listar;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_StockBajo;
DROP PROCEDURE IF EXISTS dbo.sp_Lote_Vencimientos;
DROP PROCEDURE IF EXISTS dbo.sp_Producto_MayoresSalidas;
DROP PROCEDURE IF EXISTS dbo.sp_Area_Listar;
DROP PROCEDURE IF EXISTS dbo.sp_Productos_Reactivar;
GO

PRINT N'19_eliminar_wrappers_legacy.sql ejecutado.';
GO
