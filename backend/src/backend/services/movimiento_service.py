"""Lógica de negocio de entradas, salidas y movimientos de inventario."""

from datetime import date

from backend.repositories.base import total_de
from backend.repositories.movimiento_repository import (
    listar_movimientos as listar_movimientos_repositorio,
    registrar_entrada as registrar_entrada_repositorio,
    registrar_salida as registrar_salida_repositorio,
)
from backend.schemas.movimiento import (
    EntradaCrear,
    EntradaRegistrada,
    MovimientoListado,
    SalidaCrear,
    SalidaRegistrada,
)


def listar_movimientos(
    id_producto: int | None = None,
    tipo_movimiento: str | None = None,
    id_area: int | None = None,
    desde: date | None = None,
    hasta: date | None = None,
    busqueda: str | None = None,
    pagina: int | None = None,
    tamano: int | None = None,
) -> tuple[list[MovimientoListado], int]:
    """Devuelve los movimientos filtrados y el total de coincidencias."""
    filas = listar_movimientos_repositorio(
        id_producto, tipo_movimiento, id_area, desde, hasta, busqueda, pagina, tamano
    )
    return [MovimientoListado(**fila) for fila in filas], total_de(filas)


def registrar_entrada(datos: EntradaCrear, id_usuario: int) -> EntradaRegistrada:
    """Registra una entrada; el SP actualiza el lote y el movimiento a la vez.

    ``id_usuario`` lo pone el endpoint desde el token, nunca el cliente.
    El SP también escribe la auditoría dentro de la misma transacción.
    """
    fila = registrar_entrada_repositorio(
        datos.id_producto,
        id_usuario,
        datos.cantidad,
        datos.motivo.value,
        datos.numero_lote,
        datos.fecha_vencimiento,
    )
    return EntradaRegistrada(**fila)


def registrar_salida(datos: SalidaCrear, id_usuario: int) -> SalidaRegistrada:
    """Registra una salida; el SP valida stock y vencimiento de forma atómica.

    Si ``datos.id_lote`` es ``None`` el SP aplica FEFO. La auditoría la escribe
    el propio procedimiento dentro de la transacción del movimiento.
    """
    fila = registrar_salida_repositorio(
        datos.id_producto,
        datos.id_lote,
        id_usuario,
        datos.id_area,
        datos.cantidad,
        datos.motivo,
    )
    return SalidaRegistrada(**fila)
