"""Acceso a datos de categorías mediante procedimientos almacenados."""

import pyodbc

from backend.database import obtener_conexion
from backend.errors import CategoriaDuplicada, CategoriaNoEncontrada
from backend.repositories.errores_sql import clasificar


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    tipo = clasificar(error)
    if tipo == "duplicado":
        return CategoriaDuplicada("Ya existe una categoría con ese nombre")
    if tipo == "no_encontrado":
        return CategoriaNoEncontrada("La categoría no existe")
    return error


def _filas_a_diccionarios(cursor: pyodbc.Cursor) -> list[dict]:
    """Convierte el resultado del cursor en diccionarios usando sus columnas."""
    columnas = [columna[0] for columna in cursor.description]
    return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]


def listar_categorias() -> list[dict]:
    """Ejecuta dbo.sp_Categoria_Listar (sin parámetros)."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute("EXEC dbo.sp_Categoria_Listar")
        return _filas_a_diccionarios(cursor)


def obtener_categoria(id_categoria: int) -> dict | None:
    """Ejecuta dbo.sp_Categoria_Obtener. Devuelve None si no existe."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(
            "EXEC dbo.sp_Categoria_Obtener @id_categoria = ?", id_categoria
        )
        filas = _filas_a_diccionarios(cursor)
        return filas[0] if filas else None


def crear_categoria(nombre: str, descripcion: str | None) -> int:
    """Ejecuta dbo.sp_Categoria_Crear y devuelve el id que genera el SP."""
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Categoria_Crear @nombre = ?, @descripcion = ?",
                nombre,
                descripcion,
            )
            # El SP termina con SELECT CAST(SCOPE_IDENTITY() AS INT) id_categoria
            # y su SET NOCOUNT ON hace que ese SELECT sea el primer resultado.
            return int(cursor.fetchone()[0])
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def actualizar_categoria(
    id_categoria: int,
    nombre: str,
    descripcion: str | None,
    activo: bool | None,
) -> None:
    """Ejecuta dbo.sp_Categoria_Actualizar.

    Si ``activo`` es None, el SP conserva el estado actual de la categoría.
    """
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Categoria_Actualizar "
                "@id_categoria = ?, @nombre = ?, @descripcion = ?, @activo = ?",
                id_categoria,
                nombre,
                descripcion,
                activo,
            )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_categoria(id_categoria: int) -> None:
    """Ejecuta dbo.sp_Categoria_Desactivar (eliminación lógica)."""
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Categoria_Desactivar @id_categoria = ?", id_categoria
            )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error
