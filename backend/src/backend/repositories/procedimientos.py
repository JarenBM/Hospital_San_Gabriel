"""Catálogo central de procedimientos almacenados que usa el backend.

Todos los nombres viven aquí para que ningún repositorio construya SQL
libre. ``PERMITIDOS`` actúa como lista blanca: si un nombre no está en el
catálogo, ``base`` rechaza la ejecución.
"""


class Sp:
    """Nombres canónicos de los SP del esquema dbo."""

    # Usuarios
    USUARIOS_OBTENER_SESION = "dbo.sp_Usuarios_ObtenerSesion"
    USUARIOS_OBTENER = "dbo.sp_Usuarios_Obtener"
    USUARIOS_LISTAR = "dbo.sp_Usuarios_Listar"
    USUARIOS_CREAR = "dbo.sp_Usuarios_Crear"
    USUARIOS_ACTUALIZAR = "dbo.sp_Usuarios_Actualizar"
    USUARIOS_DESACTIVAR = "dbo.sp_Usuarios_Desactivar"
    USUARIOS_CAMBIAR_PASSWORD = "dbo.sp_Usuarios_CambiarPassword"
    USUARIOS_LISTAR_ROLES = "dbo.sp_Usuarios_ListarRoles"
    USUARIOS_LISTAR_PERMISOS = "dbo.sp_Usuarios_ListarPermisos"
    USUARIOS_ASIGNAR_ROL = "dbo.sp_Usuarios_AsignarRol"
    USUARIOS_QUITAR_ROL = "dbo.sp_Usuarios_QuitarRol"

    # Roles y permisos
    ROLES_LISTAR = "dbo.sp_Roles_Listar"
    ROLES_OBTENER = "dbo.sp_Roles_Obtener"
    ROLES_CREAR = "dbo.sp_Roles_Crear"
    ROLES_ACTUALIZAR = "dbo.sp_Roles_Actualizar"
    ROLES_DESACTIVAR = "dbo.sp_Roles_Desactivar"
    ROLES_LISTAR_PERMISOS = "dbo.sp_Roles_ListarPermisos"
    ROLES_ASIGNAR_PERMISO = "dbo.sp_Roles_AsignarPermiso"
    ROLES_QUITAR_PERMISO = "dbo.sp_Roles_QuitarPermiso"
    ROLES_SINCRONIZAR_PERMISOS = "dbo.sp_Roles_SincronizarPermisos"
    PERMISOS_LISTAR = "dbo.sp_Permisos_Listar"
    PERMISOS_OBTENER = "dbo.sp_Permisos_Obtener"

    # Categorías
    CATEGORIAS_LISTAR = "dbo.sp_Categorias_Listar"
    CATEGORIAS_OBTENER = "dbo.sp_Categorias_Obtener"
    CATEGORIAS_CREAR = "dbo.sp_Categorias_Crear"
    CATEGORIAS_ACTUALIZAR = "dbo.sp_Categorias_Actualizar"
    CATEGORIAS_DESACTIVAR = "dbo.sp_Categorias_Desactivar"

    # Productos
    PRODUCTOS_LISTAR = "dbo.sp_Productos_Listar"
    PRODUCTOS_OBTENER = "dbo.sp_Productos_Obtener"
    PRODUCTOS_CREAR = "dbo.sp_Productos_Crear"
    PRODUCTOS_ACTUALIZAR = "dbo.sp_Productos_Actualizar"
    PRODUCTOS_DESACTIVAR = "dbo.sp_Productos_Desactivar"

    # Lotes
    LOTES_LISTAR_POR_PRODUCTO = "dbo.sp_Lotes_ListarPorProducto"
    LOTES_OBTENER = "dbo.sp_Lotes_Obtener"

    # Movimientos
    MOVIMIENTOS_REGISTRAR_ENTRADA = "dbo.sp_Movimientos_RegistrarEntrada"
    MOVIMIENTOS_REGISTRAR_SALIDA = "dbo.sp_Movimientos_RegistrarSalida"
    MOVIMIENTOS_LISTAR = "dbo.sp_Movimientos_Listar"
    MOVIMIENTOS_OBTENER = "dbo.sp_Movimientos_Obtener"

    # Áreas
    AREAS_LISTAR = "dbo.sp_Areas_Listar"
    AREAS_OBTENER = "dbo.sp_Areas_Obtener"
    AREAS_CREAR = "dbo.sp_Areas_Crear"
    AREAS_ACTUALIZAR = "dbo.sp_Areas_Actualizar"
    AREAS_DESACTIVAR = "dbo.sp_Areas_Desactivar"

    # Alertas, dashboard y reportes
    ALERTAS_STOCK_BAJO = "dbo.sp_Alertas_StockBajo"
    ALERTAS_POR_VENCER = "dbo.sp_Alertas_PorVencer"
    DASHBOARD_RESUMEN = "dbo.sp_Dashboard_Resumen"
    REPORTES_MAYORES_SALIDAS = "dbo.sp_Reportes_MayoresSalidas"
    REPORTES_CONSUMO_POR_AREA = "dbo.sp_Reportes_ConsumoPorArea"
    REPORTES_STOCK_VALORIZADO = "dbo.sp_Reportes_StockValorizado"

    # Auditoría
    AUDITORIA_REGISTRAR = "dbo.sp_Auditoria_Registrar"


PERMITIDOS: frozenset[str] = frozenset(
    valor for nombre, valor in vars(Sp).items() if nombre.isupper()
)
