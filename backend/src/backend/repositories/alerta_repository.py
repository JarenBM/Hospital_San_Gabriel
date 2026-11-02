"""Consultas de solo lectura para alertas de inventario."""

from datetime import date

import pyodbc

from backend.database import obtener_conexion
from backend.errors import DatosInvalidos
from backend.repositories.errores_sql import clasificar


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    if clasificar(error) == "datos_invalidos":
        return DatosInvalidos("El parámetro de la consulta no es válido")
    return error


def _filas_a_diccionarios(cursor: pyodbc.Cursor) -> list[dict]:
    """Convierte el resultado del cursor en diccionarios usando sus columnas."""
    columnas = [columna[0] for columna in cursor.description]
    return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]


def listar_stock_bajo() -> list[dict]:
    """Ejecuta dbo.sp_Producto_StockBajo (sin parámetros)."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute("EXEC dbo.sp_Producto_StockBajo")
        return _filas_a_diccionarios(cursor)


def listar_lotes_vencimientos(dias: int) -> list[dict]:
    """Ejecuta dbo.sp_Lote_Vencimientos y devuelve PROXIMO y VENCIDO.

    El SP no tiene cota inferior: con ``dias=0`` incluye todos los lotes
    vencidos con existencias, sin importar cuán antiguos sean.
    """
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute("EXEC dbo.sp_Lote_Vencimientos @dias = ?", dias)
            return _filas_a_diccionarios(cursor)
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def obtener_resumen(
    desde: date | None = None,
    hasta: date | None = None,
) -> dict:
    """Ejecuta dbo.sp_Dashboard_Resumen con su rango de fechas opcional."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(
            "EXEC dbo.sp_Dashboard_Resumen @desde = ?, @hasta = ?",
            desde,
            hasta,
        )
        columnas = [columna[0] for columna in cursor.description]
        return dict(zip(columnas, cursor.fetchone()))
