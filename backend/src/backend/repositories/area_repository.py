"""Acceso a datos de áreas hospitalarias mediante procedimientos almacenados."""

import pyodbc

from backend.errors import (
    AreaDuplicada,
    AreaNoEncontrada,
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
        return AreaDuplicada("Ya existe un área con ese nombre")
    if tipo == "no_encontrado":
        return AreaNoEncontrada("El área no existe")
    if tipo == "conflicto_area":
        return ConflictoEstado(
            "El área tiene movimientos registrados y no se puede desactivar"
        )
    if tipo == "datos_invalidos":
        return DatosInvalidos("Los datos del área no son válidos")
    return error


def listar_areas(solo_activos: bool | None = None) -> list[dict]:
    """Ejecuta dbo.sp_Areas_Listar."""
    return ejecutar_lista(Sp.AREAS_LISTAR, {"solo_activos": solo_activos})


def obtener_area(id_area: int) -> dict | None:
    """Ejecuta dbo.sp_Areas_Obtener."""
    return ejecutar_uno(Sp.AREAS_OBTENER, {"id_area": id_area})


def crear_area(nombre: str) -> int:
    """Ejecuta dbo.sp_Areas_Crear y devuelve el id generado."""
    try:
        return int(ejecutar_escalar(Sp.AREAS_CREAR, {"nombre": nombre}))
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def actualizar_area(id_area: int, nombre: str, activo: bool | None) -> None:
    """Ejecuta dbo.sp_Areas_Actualizar."""
    try:
        ejecutar_accion(
            Sp.AREAS_ACTUALIZAR,
            {"id_area": id_area, "nombre": nombre, "activo": activo},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_area(id_area: int) -> None:
    """Ejecuta dbo.sp_Areas_Desactivar (eliminación lógica)."""
    try:
        ejecutar_accion(Sp.AREAS_DESACTIVAR, {"id_area": id_area})
    except pyodbc.Error as error:
        raise _traducir_error(error) from error
