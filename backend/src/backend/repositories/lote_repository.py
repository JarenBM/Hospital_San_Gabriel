"""Acceso a datos de lotes mediante procedimientos almacenados."""

import pyodbc

from backend.database import obtener_conexion


def _filas_a_diccionarios(cursor: pyodbc.Cursor) -> list[dict]:
    """Convierte el resultado del cursor en diccionarios usando sus columnas."""
    columnas = [columna[0] for columna in cursor.description]
    return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]


def listar_lotes_por_producto(id_producto: int) -> list[dict]:
    """Ejecuta dbo.sp_Lote_ListarPorProducto (solo lectura)."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(
            "EXEC dbo.sp_Lote_ListarPorProducto @id_producto = ?", id_producto
        )
        return _filas_a_diccionarios(cursor)
