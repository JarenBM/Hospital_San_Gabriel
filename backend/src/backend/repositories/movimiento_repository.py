"""Acceso a datos de movimientos de inventario mediante procedimientos almacenados.

Las transacciones de stock viven dentro de los SP (BEGIN TRAN/COMMIT con
XACT_ABORT y ROLLBACK en el CATCH). Aquí solo se ejecuta el EXEC: el backend
no abre transacciones ni duplica esa lógica.
"""

from datetime import date

import pyodbc

from backend.database import obtener_conexion
from backend.errors import (
    DatosInvalidos,
    LoteNoEncontrado,
    LoteVencido,
    ReferenciaInvalida,
    StockInsuficiente,
)
from backend.repositories.errores_sql import clasificar


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


def _fila_a_diccionario(cursor: pyodbc.Cursor) -> dict:
    """Convierte la primera fila del cursor en un diccionario."""
    columnas = [columna[0] for columna in cursor.description]
    return dict(zip(columnas, cursor.fetchone()))


def registrar_entrada(
    id_producto: int,
    id_usuario: int,
    cantidad: int,
    motivo: str,
    numero_lote: str | None,
    fecha_vencimiento: date | None,
) -> dict:
    """Ejecuta dbo.sp_Entrada_Registrar (transaccional dentro del SP)."""
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Entrada_Registrar "
                "@id_producto = ?, @id_usuario = ?, @cantidad = ?, @motivo = ?, "
                "@numero_lote = ?, @fecha_vencimiento = ?",
                id_producto,
                id_usuario,
                cantidad,
                motivo,
                numero_lote,
                fecha_vencimiento,
            )
            return _fila_a_diccionario(cursor)
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
    """Ejecuta dbo.sp_Salida_Registrar (transaccional dentro del SP)."""
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Salida_Registrar "
                "@id_producto = ?, @id_lote = ?, @id_usuario = ?, @id_area = ?, "
                "@cantidad = ?, @motivo = ?",
                id_producto,
                id_lote,
                id_usuario,
                id_area,
                cantidad,
                motivo,
            )
            return _fila_a_diccionario(cursor)
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def listar_movimientos(
    id_producto: int | None = None,
    tipo_movimiento: str | None = None,
    id_area: int | None = None,
    desde: date | None = None,
    hasta: date | None = None,
) -> list[dict]:
    """Ejecuta dbo.sp_Movimiento_Listar con sus cinco filtros opcionales."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(
            "EXEC dbo.sp_Movimiento_Listar "
            "@id_producto = ?, @tipo_movimiento = ?, @id_area = ?, "
            "@desde = ?, @hasta = ?",
            id_producto,
            tipo_movimiento,
            id_area,
            desde,
            hasta,
        )
        columnas = [columna[0] for columna in cursor.description]
        return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]
