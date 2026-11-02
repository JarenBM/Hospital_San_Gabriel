"""Modelos de entradas, salidas y movimientos de inventario."""

from datetime import date, datetime
from enum import Enum
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

Cantidad = Annotated[int, Field(gt=0)]
IdPositivo = Annotated[int, Field(gt=0)]
Motivo = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
NumeroLote = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]


class MotivoEntrada(str, Enum):
    """Motivos admitidos para una entrada de inventario."""

    COMPRA = "Compra"
    DONACION = "Donación"
    DEVOLUCION = "Devolución"


class EntradaCrear(BaseModel):
    """Datos para dbo.sp_Entrada_Registrar.

    El usuario no viaja en el cuerpo: sale del token autenticado. Enviar
    ``id_usuario`` responde 422 para delatar clientes antiguos.
    """

    model_config = ConfigDict(extra="forbid")

    id_producto: IdPositivo
    cantidad: Cantidad
    motivo: MotivoEntrada
    numero_lote: NumeroLote | None = None
    fecha_vencimiento: date | None = None


class SalidaCrear(BaseModel):
    """Datos para dbo.sp_Salida_Registrar; el usuario sale del token."""

    model_config = ConfigDict(extra="forbid")

    id_producto: IdPositivo
    id_lote: IdPositivo
    id_area: IdPositivo
    cantidad: Cantidad
    motivo: Motivo


class EntradaRegistrada(BaseModel):
    """Resultado de dbo.sp_Entrada_Registrar."""

    id_movimiento: int
    id_lote: int
    stock_anterior: int
    stock_posterior: int


class SalidaRegistrada(BaseModel):
    """Resultado de dbo.sp_Salida_Registrar."""

    id_movimiento: int
    stock_anterior: int
    stock_posterior: int


class MovimientoListado(BaseModel):
    """Fila devuelta por dbo.sp_Movimiento_Listar."""

    id_movimiento: int
    fecha_movimiento: datetime
    tipo_movimiento: Literal["ENTRADA", "SALIDA"]
    codigo: str
    producto: str
    numero_lote: str | None = None
    fecha_vencimiento: date | None = None
    area: str | None = None
    usuario: str
    cantidad: int
    motivo: str
    stock_anterior: int
    stock_posterior: int
