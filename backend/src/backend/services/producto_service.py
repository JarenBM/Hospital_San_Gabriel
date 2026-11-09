"""Lógica de negocio de productos."""

from backend.errors import ProductoNoEncontrado
from backend.repositories import auditoria_repository
from backend.repositories.producto_repository import (
    actualizar_producto as actualizar_producto_repositorio,
    crear_producto as crear_producto_repositorio,
    desactivar_producto as desactivar_producto_repositorio,
    listar_productos as listar_productos_repositorio,
    obtener_producto as obtener_producto_repositorio,
)
from backend.schemas.producto import (
    Producto,
    ProductoActualizar,
    ProductoCrear,
    ProductoListado,
)


def listar_productos(
    busqueda: str | None = None,
    id_categoria: int | None = None,
    solo_activos: bool | None = None,
) -> list[ProductoListado]:
    """Devuelve productos con su categoría y su stock calculado."""
    filas = listar_productos_repositorio(busqueda, id_categoria, solo_activos)
    return [ProductoListado(**fila) for fila in filas]


def obtener_producto(id_producto: int) -> Producto:
    """Devuelve un producto o lanza ProductoNoEncontrado."""
    fila = obtener_producto_repositorio(id_producto)
    if fila is None:
        raise ProductoNoEncontrado(f"El producto {id_producto} no existe")
    return Producto(**fila)


def crear_producto(
    datos: ProductoCrear, id_actor: int | None = None
) -> Producto:
    """Registra un producto y devuelve su estado real en la base."""
    id_producto = crear_producto_repositorio(
        datos.id_categoria,
        datos.codigo,
        datos.nombre,
        datos.descripcion,
        datos.unidad_medida,
        datos.precio_unitario,
        datos.stock_minimo,
        datos.maneja_lotes,
        datos.requiere_vencimiento,
    )
    auditoria_repository.registrar(
        id_actor, "CREAR", "productos", id_producto, f"Código: {datos.codigo}"
    )
    return obtener_producto(id_producto)


def actualizar_producto(
    id_producto: int,
    datos: ProductoActualizar,
    id_actor: int | None = None,
) -> Producto:
    """Actualiza un producto y devuelve su estado final.

    ``activo`` no se modifica aquí: se envía None para conservar el estado.
    """
    actualizar_producto_repositorio(
        id_producto,
        datos.id_categoria,
        datos.codigo,
        datos.nombre,
        datos.descripcion,
        datos.unidad_medida,
        datos.precio_unitario,
        datos.stock_minimo,
        activo=None,
    )
    auditoria_repository.registrar(
        id_actor, "ACTUALIZAR", "productos", id_producto, f"Código: {datos.codigo}"
    )
    return obtener_producto(id_producto)


def desactivar_producto(
    id_producto: int, id_actor: int | None = None
) -> None:
    """Desactiva un producto (el SP bloquea si tiene existencias)."""
    desactivar_producto_repositorio(id_producto)
    auditoria_repository.registrar(
        id_actor, "DESACTIVAR", "productos", id_producto
    )
