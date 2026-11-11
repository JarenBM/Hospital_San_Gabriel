"""Lógica de negocio de entradas, salidas y movimientos de inventario."""

from datetime import date

from backend.repositories import auditoria_repository
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
    """
    fila = registrar_entrada_repositorio(
        datos.id_producto,
        id_usuario,
        datos.cantidad,
        datos.motivo.value,
        datos.numero_lote,
        datos.fecha_vencimiento,
    )
    auditoria_repository.registrar(
        id_usuario,
        "ENTRADA",
        "movimientos",
        fila.get("id_movimiento"),
        f"Producto: {datos.id_producto}, cantidad: {datos.cantidad}",
    )
    return EntradaRegistrada(**fila)


def registrar_salida(datos: SalidaCrear, id_usuario: int) -> SalidaRegistrada:
    """Registra una salida; el SP valida stock y vencimiento de forma atómica."""
    fila = registrar_salida_repositorio(
        datos.id_producto,
        datos.id_lote,
        id_usuario,
        datos.id_area,
        datos.cantidad,
        datos.motivo,
    )
    auditoria_repository.registrar(
        id_usuario,
        "SALIDA",
        "movimientos",
        fila.get("id_movimiento"),
        f"Producto: {datos.id_producto}, área: {datos.id_area}, "
        f"cantidad: {datos.cantidad}",
    )
    return SalidaRegistrada(**fila)
