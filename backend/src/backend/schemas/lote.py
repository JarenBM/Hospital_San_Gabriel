"""Modelos de lotes de inventario."""

from datetime import date, datetime

from pydantic import BaseModel


class Lote(BaseModel):
    """Fila devuelta por dbo.sp_Lote_ListarPorProducto.

    El stock solo cambia mediante entradas y salidas, nunca por un CRUD.
    """

    id_lote: int
    id_producto: int
    numero_lote: str | None = None
    fecha_vencimiento: date | None = None
    stock_actual: int
    fecha_registro: datetime
    vencido: bool
