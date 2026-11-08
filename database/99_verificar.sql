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
