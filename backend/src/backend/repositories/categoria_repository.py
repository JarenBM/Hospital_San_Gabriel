"""Acceso a datos de categorías mediante procedimientos almacenados."""

import pyodbc

from backend.errors import (
    CategoriaDuplicada,
    CategoriaNoEncontrada,
    ConflictoEstado,
    DatosInvalidos,
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
        return CategoriaDuplicada("Ya existe una categoría con ese nombre")
    if tipo == "no_encontrado":
        return CategoriaNoEncontrada("La categoría no existe")
    if tipo == "conflicto_categoria":
        return ConflictoEstado("La categoría tiene productos activos")
    if tipo == "datos_invalidos":
        return DatosInvalidos("Los datos de la categoría no son válidos")
    return error


def listar_categorias(solo_activos: bool | None = None) -> list[dict]:
    """Ejecuta dbo.sp_Categorias_Listar."""
    return ejecutar_lista(Sp.CATEGORIAS_LISTAR, {"solo_activos": solo_activos})


def obtener_categoria(id_categoria: int) -> dict | None:
    """Ejecuta dbo.sp_Categorias_Obtener."""
    return ejecutar_uno(Sp.CATEGORIAS_OBTENER, {"id_categoria": id_categoria})


def crear_categoria(nombre: str, descripcion: str | None) -> int:
    """Ejecuta dbo.sp_Categorias_Crear y devuelve el id generado."""
    try:
        return int(
            ejecutar_escalar(
                Sp.CATEGORIAS_CREAR,
                {"nombre": nombre, "descripcion": descripcion},
            )
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def actualizar_categoria(
    id_categoria: int,
    nombre: str,
    descripcion: str | None,
    activo: bool | None,
) -> None:
    """Ejecuta dbo.sp_Categorias_Actualizar."""
    try:
        ejecutar_accion(
            Sp.CATEGORIAS_ACTUALIZAR,
            {
                "id_categoria": id_categoria,
                "nombre": nombre,
                "descripcion": descripcion,
                "activo": activo,
            },
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_categoria(id_categoria: int) -> None:
    """Ejecuta dbo.sp_Categorias_Desactivar (eliminación lógica)."""
    try:
        ejecutar_accion(Sp.CATEGORIAS_DESACTIVAR, {"id_categoria": id_categoria})
    except pyodbc.Error as error:
        raise _traducir_error(error) from error
