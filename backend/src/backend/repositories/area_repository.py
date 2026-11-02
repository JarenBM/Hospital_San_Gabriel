"""Acceso a datos de áreas hospitalarias mediante procedimientos almacenados."""

import pyodbc

from backend.database import obtener_conexion


def _filas_a_diccionarios(cursor: pyodbc.Cursor) -> list[dict]:
    """Convierte el resultado del cursor en diccionarios usando sus columnas."""
    columnas = [columna[0] for columna in cursor.description]
    return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]


def listar_areas() -> list[dict]:
    """Ejecuta dbo.sp_Area_Listar (sin parámetros)."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute("EXEC dbo.sp_Area_Listar")
        return _filas_a_diccionarios(cursor)
