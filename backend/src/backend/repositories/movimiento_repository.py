"""Acceso a datos de movimientos de inventario mediante procedimientos almacenados.

Las transacciones de stock viven dentro de los SP (BEGIN TRAN/COMMIT con
XACT_ABORT y ROLLBACK en el CATCH). Aquí solo se ejecuta el EXEC: el backend
no abre transacciones ni duplica esa lógica.
"""

from datetime import date

import pyodbc

from backend.errors import (
    DatosInvalidos,
    LoteNoEncontrado,
    LoteVencido,
    ReferenciaInvalida,
    StockInsuficiente,
)
from backend.repositories.base import (
    ejecutar_lista,
    ejecutar_uno,
)
from backend.repositories.errores_sql import clasificar
from backend.repositories.procedimientos import Sp


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    tipo = clasificar(error)
    if tipo == "lote_no_encontrado":
        return LoteNoEncontrado("El lote indicado no existe")
    if tipo == "lote_vencido":
        return LoteVencido("El lote está vencido")
    if tipo == "stock_insuficiente":
        return StockInsuficiente("No hay existencias suficientes en el lote")
    if tipo == "usuario_invalido":
        return ReferenciaInvalida("El usuario no existe o está inactivo")
    if tipo == "producto_invalido":
        return ReferenciaInvalida("El producto no existe o está inactivo")
    if tipo == "area_invalida":
        return ReferenciaInvalida("El área no existe o está inactiva")
    if tipo == "datos_inventario_invalidos":
        return DatosInvalidos("Datos del movimiento no válidos")
    return error


def registrar_entrada(
    id_producto: int,
    id_usuario: int,
    cantidad: int,
    motivo: str,
    numero_lote: str | None,
    fecha_vencimiento: date | None,
) -> dict:
    """Ejecuta dbo.sp_Movimientos_RegistrarEntrada."""
    try:
        fila = ejecutar_uno(
            Sp.MOVIMIENTOS_REGISTRAR_ENTRADA,
            {
                "id_producto": id_producto,
                "id_usuario": id_usuario,
                "cantidad": cantidad,
                "motivo": motivo,
                "numero_lote": numero_lote,
                "fecha_vencimiento": fecha_vencimiento,
            },
        )
        return fila or {}
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def registrar_salida(
    id_producto: int,
    id_lote: int,
    id_usuario: int,
    id_area: int,
    cantidad: int,
    motivo: str,
) -> dict:
    """Ejecuta dbo.sp_Movimientos_RegistrarSalida."""
    try:
        fila = ejecutar_uno(
            Sp.MOVIMIENTOS_REGISTRAR_SALIDA,
            {
                "id_producto": id_producto,
                "id_lote": id_lote,
                "id_usuario": id_usuario,
                "id_area": id_area,
                "cantidad": cantidad,
                "motivo": motivo,
            },
        )
        return fila or {}
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def listar_movimientos(
    id_producto: int | None = None,
    tipo_movimiento: str | None = None,
    id_area: int | None = None,
    desde: date | None = None,
    hasta: date | None = None,
) -> list[dict]:
    """Ejecuta dbo.sp_Movimientos_Listar con sus cinco filtros opcionales."""
    return ejecutar_lista(
        Sp.MOVIMIENTOS_LISTAR,
        {
            "id_producto": id_producto,
            "tipo_movimiento": tipo_movimiento,
            "id_area": id_area,
            "desde": desde,
            "hasta": hasta,
        },
    )


def obtener_movimiento(id_movimiento: int) -> dict | None:
    """Ejecuta dbo.sp_Movimientos_Obtener."""
    return ejecutar_uno(
        Sp.MOVIMIENTOS_OBTENER, {"id_movimiento": id_movimiento}
    )
