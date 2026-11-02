"""Modelos de alertas y control de inventario (solo lectura)."""

from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel


class ProductoStockBajo(BaseModel):
    """Fila devuelta por dbo.sp_Producto_StockBajo."""

    id_producto: int
    codigo: str
    nombre: str
    stock_minimo: int
    stock_disponible: int


class LoteAlerta(BaseModel):
    """Fila devuelta por dbo.sp_Lote_Vencimientos.

    ``estado`` lo calcula SQL Server: VENCIDO si la fecha es anterior a hoy,
    PROXIMO si cae entre hoy y el límite consultado.
    """

    codigo: str
    nombre: str
    numero_lote: str | None = None
    fecha_vencimiento: date
    stock_actual: int
    estado: Literal["PROXIMO", "VENCIDO"]


class ResumenInventario(BaseModel):
    """Fila devuelta por dbo.sp_Dashboard_Resumen."""

    productos_activos: int
    productos_stock_bajo: int
    lotes_vencidos: int
    lotes_proximos_vencer: int
    valor_referencial_inventario: Decimal
    movimientos_periodo: int
