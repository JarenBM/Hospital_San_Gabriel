"""Acceso a datos de productos mediante procedimientos almacenados."""

from decimal import Decimal

import pyodbc

from backend.database import obtener_conexion
from backend.errors import (
    CategoriaInvalida,
    DatosInvalidos,
    ProductoDuplicado,
    ProductoNoEncontrado,
)
from backend.repositories.errores_sql import clasificar


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    tipo = clasificar(error)
    if tipo == "duplicado":
        return ProductoDuplicado("Ya existe un producto con ese código")
    if tipo == "no_encontrado":
        return ProductoNoEncontrado("El producto no existe")
    if tipo == "referencia_invalida":
        return CategoriaInvalida("La categoría no existe o está inactiva")
    if tipo == "datos_invalidos":
        return DatosInvalidos("Los datos del producto no son válidos")
    return error


def _filas_a_diccionarios(cursor: pyodbc.Cursor) -> list[dict]:
    """Convierte el resultado del cursor en diccionarios usando sus columnas."""
    columnas = [columna[0] for columna in cursor.description]
    return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]


def listar_productos(
    busqueda: str | None = None,
    id_categoria: int | None = None,
    solo_activos: bool | None = None,
) -> list[dict]:
    """Ejecuta dbo.sp_Producto_Listar con sus tres filtros opcionales."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(
            "EXEC dbo.sp_Producto_Listar "
            "@busqueda = ?, @id_categoria = ?, @solo_activos = ?",
            busqueda,
            id_categoria,
            solo_activos,
        )
        return _filas_a_diccionarios(cursor)


def obtener_producto(id_producto: int) -> dict | None:
    """Ejecuta dbo.sp_Producto_Obtener. Devuelve None si no existe."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(
            "EXEC dbo.sp_Producto_Obtener @id_producto = ?", id_producto
        )
        filas = _filas_a_diccionarios(cursor)
        return filas[0] if filas else None


def crear_producto(
    id_categoria: int,
    codigo: str,
    nombre: str,
    descripcion: str | None,
    unidad_medida: str,
    precio_unitario: Decimal,
    stock_minimo: int,
    maneja_lotes: bool,
    requiere_vencimiento: bool,
) -> int:
    """Ejecuta dbo.sp_Producto_Crear y devuelve el id que genera el SP."""
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Producto_Crear "
                "@id_categoria = ?, @codigo = ?, @nombre = ?, @descripcion = ?, "
                "@unidad_medida = ?, @precio_unitario = ?, @stock_minimo = ?, "
                "@maneja_lotes = ?, @requiere_vencimiento = ?",
                id_categoria,
                codigo,
                nombre,
                descripcion,
                unidad_medida,
                precio_unitario,
                stock_minimo,
                maneja_lotes,
                requiere_vencimiento,
            )
            # El SP termina con SELECT CAST(SCOPE_IDENTITY() AS INT) id_producto.
            return int(cursor.fetchone()[0])
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def actualizar_producto(
    id_producto: int,
    id_categoria: int,
    codigo: str,
    nombre: str,
    descripcion: str | None,
    unidad_medida: str,
    precio_unitario: Decimal,
    stock_minimo: int,
) -> None:
    """Ejecuta dbo.sp_Producto_Actualizar.

    El SP no modifica maneja_lotes ni requiere_vencimiento.
    """
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Producto_Actualizar "
                "@id_producto = ?, @id_categoria = ?, @codigo = ?, @nombre = ?, "
                "@descripcion = ?, @unidad_medida = ?, @precio_unitario = ?, "
                "@stock_minimo = ?",
                id_producto,
                id_categoria,
                codigo,
                nombre,
                descripcion,
                unidad_medida,
                precio_unitario,
                stock_minimo,
            )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_producto(id_producto: int) -> None:
    """Ejecuta dbo.sp_Producto_Desactivar (eliminación lógica)."""
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute(
                "EXEC dbo.sp_Producto_Desactivar @id_producto = ?", id_producto
            )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error
