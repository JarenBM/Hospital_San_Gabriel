"""Lógica de negocio de reportes."""

from datetime import date

from backend.repositories.reporte_repository import (
    consumo_por_area as consumo_por_area_repositorio,
    mayores_salidas as mayores_salidas_repositorio,
    stock_valorizado as stock_valorizado_repositorio,
)
from backend.schemas.reporte import ConsumoArea, MayorSalida, StockValorizado


def mayores_salidas(
    desde: date, hasta: date, top: int = 10
) -> list[MayorSalida]:
    """Productos con más unidades despachadas en el rango."""
    filas = mayores_salidas_repositorio(desde, hasta, top)
    return [MayorSalida(**fila) for fila in filas]


def consumo_por_area(desde: date, hasta: date) -> list[ConsumoArea]:
    """Salidas agrupadas por área hospitalaria."""
    filas = consumo_por_area_repositorio(desde, hasta)
    return [ConsumoArea(**fila) for fila in filas]


def stock_valorizado() -> list[StockValorizado]:
    """Inventario activo valuado a precio unitario."""
    filas = stock_valorizado_repositorio()
    return [StockValorizado(**fila) for fila in filas]
