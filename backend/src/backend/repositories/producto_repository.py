"""Acceso a datos de productos mediante procedimientos almacenados."""

from decimal import Decimal

import pyodbc

from backend.errors import (
    CategoriaInvalida,
    ConflictoEstado,
    DatosInvalidos,
    ProductoDuplicado,
    ProductoNoEncontrado,
)
from backend.repositories.base import (
    ejecutar_accion,
    ejecutar_escalar,
    ejecutar_lista,
    ejecutar_uno,
)
from backend.repositories.errores_sql import clasificar
from backend.repositories.procedimientos import Sp


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    tipo = clasificar(error)
    if tipo == "duplicado":
        return ProductoDuplicado("Ya existe un producto con ese código")
    if tipo == "no_encontrado":
        return ProductoNoEncontrado("El producto no existe")
    if tipo == "referencia_invalida":
        return CategoriaInvalida("La categoría no existe o está inactiva")
    if tipo == "conflicto_stock":
        return ConflictoEstado("No se puede desactivar un producto con existencias")
    if tipo == "datos_invalidos":
        return DatosInvalidos("Los datos del producto no son válidos")
    return error


def listar_productos(
    busqueda: str | None = None,
    id_categoria: int | None = None,
    solo_activos: bool | None = None,
    pagina: int | None = None,
    tamano: int | None = None,
) -> list[dict]:
    """Ejecuta dbo.sp_Productos_Listar con sus filtros y paginación opcionales."""
    return ejecutar_lista(
        Sp.PRODUCTOS_LISTAR,
        {
            "busqueda": busqueda,
            "id_categoria": id_categoria,
            "solo_activos": solo_activos,
            "pagina": pagina,
            "tamano": tamano,
        },
    )


def obtener_producto(id_producto: int) -> dict | None:
    """Ejecuta dbo.sp_Productos_Obtener."""
    return ejecutar_uno(Sp.PRODUCTOS_OBTENER, {"id_producto": id_producto})


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
    """Ejecuta dbo.sp_Productos_Crear y devuelve el id generado."""
    try:
        return int(
            ejecutar_escalar(
                Sp.PRODUCTOS_CREAR,
                {
                    "id_categoria": id_categoria,
                    "codigo": codigo,
                    "nombre": nombre,
                    "descripcion": descripcion,
                    "unidad_medida": unidad_medida,
                    "precio_unitario": precio_unitario,
                    "stock_minimo": stock_minimo,
                    "maneja_lotes": maneja_lotes,
                    "requiere_vencimiento": requiere_vencimiento,
                },
            )
        )
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
    activo: bool | None = None,
) -> None:
    """Ejecuta dbo.sp_Productos_Actualizar.

    ``activo`` es opcional: None conserva el estado actual.
    """
    try:
        ejecutar_accion(
            Sp.PRODUCTOS_ACTUALIZAR,
            {
                "id_producto": id_producto,
                "id_categoria": id_categoria,
                "codigo": codigo,
                "nombre": nombre,
                "descripcion": descripcion,
                "unidad_medida": unidad_medida,
                "precio_unitario": precio_unitario,
                "stock_minimo": stock_minimo,
                "activo": activo,
            },
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_producto(id_producto: int) -> None:
    """Ejecuta dbo.sp_Productos_Desactivar (eliminación lógica)."""
    try:
        ejecutar_accion(Sp.PRODUCTOS_DESACTIVAR, {"id_producto": id_producto})
    except pyodbc.Error as error:
        raise _traducir_error(error) from error
