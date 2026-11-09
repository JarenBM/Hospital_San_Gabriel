"""Acceso a datos de roles y permisos mediante procedimientos almacenados."""

import pyodbc

from backend.errors import (
    ConflictoEstado,
    DatosInvalidos,
    PermisoNoEncontrado,
    RolDuplicado,
    RolNoEncontrado,
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
        return RolDuplicado("Ya existe un rol con ese nombre")
    if tipo == "no_encontrado":
        return RolNoEncontrado("El rol no existe")
    if tipo == "permiso_no_encontrado":
        return PermisoNoEncontrado("El permiso no existe")
    if tipo == "rol_protegido":
        return ConflictoEstado("El rol ADMINISTRADOR no se puede alterar")
    if tipo == "datos_invalidos":
        return DatosInvalidos("Los datos del rol no son válidos")
    return error


def listar_roles(solo_activos: bool | None = None) -> list[dict]:
    """Ejecuta dbo.sp_Roles_Listar."""
    return ejecutar_lista(Sp.ROLES_LISTAR, {"solo_activos": solo_activos})


def obtener_rol(id_rol: int) -> dict | None:
    """Ejecuta dbo.sp_Roles_Obtener."""
    return ejecutar_uno(Sp.ROLES_OBTENER, {"id_rol": id_rol})


def crear_rol(nombre: str, descripcion: str | None) -> int:
    """Ejecuta dbo.sp_Roles_Crear y devuelve el id generado."""
    try:
        return int(
            ejecutar_escalar(
                Sp.ROLES_CREAR,
                {"nombre": nombre, "descripcion": descripcion},
            )
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def actualizar_rol(
    id_rol: int,
    nombre: str,
    descripcion: str | None,
    activo: bool | None,
) -> None:
    """Ejecuta dbo.sp_Roles_Actualizar."""
    try:
        ejecutar_accion(
            Sp.ROLES_ACTUALIZAR,
            {
                "id_rol": id_rol,
                "nombre": nombre,
                "descripcion": descripcion,
                "activo": activo,
            },
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_rol(id_rol: int) -> None:
    """Ejecuta dbo.sp_Roles_Desactivar."""
    try:
        ejecutar_accion(Sp.ROLES_DESACTIVAR, {"id_rol": id_rol})
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def listar_permisos_rol(id_rol: int) -> list[dict]:
    """Ejecuta dbo.sp_Roles_ListarPermisos."""
    return ejecutar_lista(Sp.ROLES_LISTAR_PERMISOS, {"id_rol": id_rol})


def asignar_permiso(id_rol: int, id_permiso: int) -> None:
    """Ejecuta dbo.sp_Roles_AsignarPermiso."""
    try:
        ejecutar_accion(
            Sp.ROLES_ASIGNAR_PERMISO,
            {"id_rol": id_rol, "id_permiso": id_permiso},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def quitar_permiso(id_rol: int, id_permiso: int) -> None:
    """Ejecuta dbo.sp_Roles_QuitarPermiso."""
    try:
        ejecutar_accion(
            Sp.ROLES_QUITAR_PERMISO,
            {"id_rol": id_rol, "id_permiso": id_permiso},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def sincronizar_permisos(id_rol: int, permisos_json: str) -> int:
    """Ejecuta dbo.sp_Roles_SincronizarPermisos y devuelve el total aplicado."""
    try:
        return int(
            ejecutar_escalar(
                Sp.ROLES_SINCRONIZAR_PERMISOS,
                {"id_rol": id_rol, "permisos_json": permisos_json},
            )
            or 0
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def listar_permisos(modulo: str | None = None) -> list[dict]:
    """Ejecuta dbo.sp_Permisos_Listar."""
    return ejecutar_lista(Sp.PERMISOS_LISTAR, {"modulo": modulo})


def obtener_permiso(id_permiso: int) -> dict | None:
    """Ejecuta dbo.sp_Permisos_Obtener."""
    return ejecutar_uno(Sp.PERMISOS_OBTENER, {"id_permiso": id_permiso})
