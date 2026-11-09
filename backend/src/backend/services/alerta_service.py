"""Lógica de negocio de alertas de inventario (solo lectura)."""

from datetime import date

from backend.repositories.alerta_repository import (
    listar_lotes_vencimientos as listar_lotes_vencimientos_repositorio,
    listar_stock_bajo as listar_stock_bajo_repositorio,
    obtener_resumen as obtener_resumen_repositorio,
)
from backend.schemas.alerta import LoteAlerta, ProductoStockBajo, ResumenInventario


def listar_stock_bajo() -> list[ProductoStockBajo]:
    """Productos activos cuyo stock disponible no supera su stock mínimo."""
    filas = listar_stock_bajo_repositorio()
    return [ProductoStockBajo(**fila) for fila in filas]


def listar_por_vencer(dias: int = 30) -> list[LoteAlerta]:
    """Lotes que vencen desde hoy hasta ``dias`` días adelante."""
    filas = listar_lotes_vencimientos_repositorio(dias)
    return [
        LoteAlerta(**fila) for fila in filas if fila["estado"] == "PROXIMO"
    ]


def listar_vencidos() -> list[LoteAlerta]:
    """Lotes ya vencidos que todavía tienen existencias.

    Se consulta con ``dias=0`` para no imponer un límite futuro: el SP solo
    filtra por ``fecha_vencimiento <= hoy``, así que incluye vencimientos
    antiguos sin excepción.
    """
    filas = listar_lotes_vencimientos_repositorio(0)
    return [LoteAlerta(**fila) for fila in filas if fila["estado"] == "VENCIDO"]


def obtener_resumen(
    desde: date | None = None,
    hasta: date | None = None,
) -> ResumenInventario:
    """Conteos generales de inventario y movimientos del período."""
    fila = obtener_resumen_repositorio(desde, hasta)
    return ResumenInventario(**fila)
