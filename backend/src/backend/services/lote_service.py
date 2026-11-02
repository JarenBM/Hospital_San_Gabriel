"""Lógica de negocio de lotes."""

from backend.repositories.lote_repository import (
    listar_lotes_por_producto as listar_lotes_repositorio,
)
from backend.schemas.lote import Lote
from backend.services.producto_service import obtener_producto


def listar_lotes_por_producto(id_producto: int) -> list[Lote]:
    """Devuelve los lotes de un producto.

    Valida que el producto exista reutilizando el servicio de productos:
    el SP devuelve una lista vacía tanto si no hay lotes como si el producto
    no existe, y aquí queremos distinguir ambos casos con un 404.
    """
    obtener_producto(id_producto)
    filas = listar_lotes_repositorio(id_producto)
    return [Lote(**fila) for fila in filas]
