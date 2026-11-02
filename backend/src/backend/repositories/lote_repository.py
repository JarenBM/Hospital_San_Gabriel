"""Acceso a datos de lotes mediante procedimientos almacenados."""

from backend.repositories.base import ejecutar_lista, ejecutar_uno
from backend.repositories.procedimientos import Sp


def listar_lotes_por_producto(id_producto: int) -> list[dict]:
    """Ejecuta dbo.sp_Lotes_ListarPorProducto (solo lectura)."""
    return ejecutar_lista(
        Sp.LOTES_LISTAR_POR_PRODUCTO, {"id_producto": id_producto}
    )


def obtener_lote(id_lote: int) -> dict | None:
    """Ejecuta dbo.sp_Lotes_Obtener."""
    return ejecutar_uno(Sp.LOTES_OBTENER, {"id_lote": id_lote})
