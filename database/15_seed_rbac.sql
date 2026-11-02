-- SIGIH | 15 - RBAC: roles, permisos y asignaciones iniciales
-- Idempotente. Los códigos de permiso son modulo:accion.

USE SIGIH;
GO

-- Roles base
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ADMINISTRADOR')
    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (N'ADMINISTRADOR', N'Acceso total al sistema', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ALMACEN')
    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (N'ALMACEN', N'Gestión de inventario y movimientos', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'CONSULTA')
    INSERT dbo.Roles (nombre, descripcion, activo)
    VALUES (N'CONSULTA', N'Acceso de solo lectura', 1);

-- Autocorregir descripciones si el rol ya existía con otro texto.
UPDATE dbo.Roles
SET descripcion = CASE nombre
        WHEN N'ADMINISTRADOR' THEN N'Acceso total al sistema'
        WHEN N'ALMACEN'       THEN N'Gestión de inventario y movimientos'
        WHEN N'CONSULTA'      THEN N'Acceso de solo lectura'
        ELSE descripcion
    END
WHERE nombre IN (N'ADMINISTRADOR', N'ALMACEN', N'CONSULTA');

-- Permisos
;WITH nuevos AS (
    SELECT *
    FROM (VALUES
        (N'categorias:leer',      N'categorias', N'Consultar categorías'),
        (N'categorias:escribir',  N'categorias', N'Crear, editar y desactivar categorías'),
        (N'productos:leer',       N'productos',  N'Consultar productos'),
        (N'productos:escribir',   N'productos',  N'Crear, editar y desactivar productos'),
        (N'lotes:leer',           N'lotes',      N'Consultar lotes'),
        (N'movimientos:leer',     N'movimientos',N'Consultar movimientos'),
        (N'movimientos:entrada',  N'movimientos',N'Registrar entradas'),
        (N'movimientos:salida',   N'movimientos',N'Registrar salidas'),
        (N'areas:leer',           N'areas',      N'Consultar áreas'),
        (N'areas:escribir',       N'areas',      N'Crear, editar y desactivar áreas'),
        (N'alertas:leer',         N'alertas',    N'Consultar alertas de inventario'),
        (N'dashboard:leer',       N'dashboard',  N'Consultar el dashboard'),
        (N'reportes:leer',        N'reportes',   N'Consultar reportes'),
        (N'usuarios:gestionar',   N'usuarios',   N'Gestionar usuarios'),
        (N'roles:gestionar',      N'roles',      N'Gestionar roles y permisos'),
        (N'auditoria:leer',       N'auditoria',  N'Consultar auditoría')
    ) v(codigo, modulo, descripcion)
)
INSERT dbo.Permisos (codigo, modulo, descripcion)
SELECT n.codigo, n.modulo, n.descripcion
FROM nuevos n
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Permisos p WHERE p.codigo = n.codigo
);

-- Autocorregir módulo/descripción de permisos ya existentes.
;WITH nuevos AS (
    SELECT *
    FROM (VALUES
        (N'categorias:leer',      N'categorias', N'Consultar categorías'),
        (N'categorias:escribir',  N'categorias', N'Crear, editar y desactivar categorías'),
        (N'productos:leer',       N'productos',  N'Consultar productos'),
        (N'productos:escribir',   N'productos',  N'Crear, editar y desactivar productos'),
        (N'lotes:leer',           N'lotes',      N'Consultar lotes'),
        (N'movimientos:leer',     N'movimientos',N'Consultar movimientos'),
        (N'movimientos:entrada',  N'movimientos',N'Registrar entradas'),
        (N'movimientos:salida',   N'movimientos',N'Registrar salidas'),
        (N'areas:leer',           N'areas',      N'Consultar áreas'),
        (N'areas:escribir',       N'areas',      N'Crear, editar y desactivar áreas'),
        (N'alertas:leer',         N'alertas',    N'Consultar alertas de inventario'),
        (N'dashboard:leer',       N'dashboard',  N'Consultar el dashboard'),
        (N'reportes:leer',        N'reportes',   N'Consultar reportes'),
        (N'usuarios:gestionar',   N'usuarios',   N'Gestionar usuarios'),
        (N'roles:gestionar',      N'roles',      N'Gestionar roles y permisos'),
        (N'auditoria:leer',       N'auditoria',  N'Consultar auditoría')
    ) v(codigo, modulo, descripcion)
)
UPDATE p
SET modulo = n.modulo,
    descripcion = n.descripcion
FROM dbo.Permisos p
JOIN nuevos n ON n.codigo = p.codigo;

-- ADMINISTRADOR: todos los permisos
INSERT dbo.RolesPermisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM dbo.Roles r
CROSS JOIN dbo.Permisos p
WHERE r.nombre = N'ADMINISTRADOR'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolesPermisos rp
      WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso
  );

-- ALMACEN: inventario operativo
INSERT dbo.RolesPermisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM dbo.Roles r
JOIN dbo.Permisos p ON p.codigo IN (
    N'categorias:leer',
    N'productos:leer', N'productos:escribir',
    N'lotes:leer',
    N'movimientos:leer', N'movimientos:entrada', N'movimientos:salida',
    N'areas:leer',
    N'alertas:leer',
    N'dashboard:leer',
    N'reportes:leer'
)
WHERE r.nombre = N'ALMACEN'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolesPermisos rp
      WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso
  );

-- CONSULTA: solo lectura
INSERT dbo.RolesPermisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM dbo.Roles r
JOIN dbo.Permisos p ON p.codigo IN (
    N'categorias:leer',
    N'productos:leer',
    N'lotes:leer',
    N'movimientos:leer',
    N'areas:leer',
    N'alertas:leer',
    N'dashboard:leer',
    N'reportes:leer'
)
WHERE r.nombre = N'CONSULTA'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolesPermisos rp
      WHERE rp.id_rol = r.id_rol AND rp.id_permiso = p.id_permiso
  );

-- Asignar ADMINISTRADOR al administrador ya existente (si lo hay).
INSERT dbo.UsuariosRoles (id_usuario, id_rol)
SELECT u.id_usuario, r.id_rol
FROM dbo.Usuarios u
JOIN dbo.Roles r ON r.nombre = N'ADMINISTRADOR'
WHERE u.email = N'admin.desarrollo@sigih.test'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.UsuariosRoles ur
      WHERE ur.id_usuario = u.id_usuario AND ur.id_rol = r.id_rol
  );

PRINT N'15_seed_rbac.sql ejecutado.';
GO
