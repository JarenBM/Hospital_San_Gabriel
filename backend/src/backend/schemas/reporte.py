"""Modelos de reportes de inventario."""

from decimal import Decimal

from pydantic import BaseModel


class MayorSalida(BaseModel):
    """Fila de dbo.sp_Reportes_MayoresSalidas."""

    id_producto: int
    codigo: str
    nombre: str
    total_salidas: int


class ConsumoArea(BaseModel):
    """Fila de dbo.sp_Reportes_ConsumoPorArea."""

    id_area: int
    area: str
    total_movimientos: int
    total_unidades: int


class StockValorizado(BaseModel):
    """Fila de dbo.sp_Reportes_StockValorizado."""

    id_producto: int
    codigo: str
    nombre: str
    categoria: str
    stock_total: int
    precio_unitario: Decimal
    valor_total: Decimal
