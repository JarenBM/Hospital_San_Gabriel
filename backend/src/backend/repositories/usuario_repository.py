"""Acceso a datos de usuarios y sesión mediante procedimientos almacenados."""

import pyodbc

from backend.errors import (
    ConflictoEstado,
    DatosInvalidos,
    RolNoEncontrado,
    UsuarioDuplicado,
    UsuarioNoEncontrado,
)
from backend.repositories.base import (
    ejecutar_accion,
    ejecutar_escalar,
    ejecutar_lista,
    ejecutar_multiples,
    ejecutar_uno,
)
from backend.repositories.errores_sql import clasificar
from backend.repositories.procedimientos import Sp


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    tipo = clasificar(error)
    if tipo == "duplicado":
        return UsuarioDuplicado("Ya existe un usuario con ese correo")
    if tipo == "no_encontrado":
        return UsuarioNoEncontrado("El usuario no existe")
    if tipo == "rol_invalido":
        return RolNoEncontrado("El rol no existe o está inactivo")
    if tipo == "ultimo_admin":
        return ConflictoEstado(
            "No se puede dejar el sistema sin un administrador activo"
        )
    if tipo == "datos_invalidos":
        return DatosInvalidos("Los datos del usuario no son válidos")
    return error


def obtener_sesion(email: str) -> dict:
    """Ejecuta dbo.sp_Usuarios_ObtenerSesion.

    Devuelve ``usuario`` (incluido el hash), ``roles`` y ``permisos``.
    El SP entrega tres result sets en ese orden.
    """
    resultados = ejecutar_multiples(
        Sp.USUARIOS_OBTENER_SESION, {"email": email}
    )
    usuario = resultados[0][0] if resultados and resultados[0] else None
    roles = resultados[1] if len(resultados) > 1 else []
    permisos = resultados[2] if len(resultados) > 2 else []
    return {"usuario": usuario, "roles": roles, "permisos": permisos}


def obtener_usuario(id_usuario: int) -> dict | None:
    """Ejecuta dbo.sp_Usuarios_Obtener."""
    return ejecutar_uno(Sp.USUARIOS_OBTENER, {"id_usuario": id_usuario})


def listar_usuarios(
    busqueda: str | None = None,
    id_rol: int | None = None,
    solo_activos: bool | None = None,
    pagina: int | None = None,
    tamano: int | None = None,
) -> list[dict]:
    """Ejecuta dbo.sp_Usuarios_Listar con sus filtros y paginación opcionales."""
    return ejecutar_lista(
        Sp.USUARIOS_LISTAR,
        {
            "busqueda": busqueda,
            "id_rol": id_rol,
            "solo_activos": solo_activos,
            "pagina": pagina,
            "tamano": tamano,
        },
    )


def crear_usuario(
    nombre: str,
    email: str,
    password_hash: str,
    id_rol: int | None = None,
) -> int:
    """Ejecuta dbo.sp_Usuarios_Crear y devuelve el id generado."""
    try:
        return int(
            ejecutar_escalar(
                Sp.USUARIOS_CREAR,
                {
                    "nombre": nombre,
                    "email": email,
                    "password_hash": password_hash,
                    "id_rol": id_rol,
                },
            )
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def actualizar_usuario(
    id_usuario: int,
    nombre: str,
    email: str,
    activo: bool | None = None,
) -> None:
    """Ejecuta dbo.sp_Usuarios_Actualizar."""
    try:
        ejecutar_accion(
            Sp.USUARIOS_ACTUALIZAR,
            {
                "id_usuario": id_usuario,
                "nombre": nombre,
                "email": email,
                "activo": activo,
            },
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def desactivar_usuario(id_usuario: int) -> None:
    """Ejecuta dbo.sp_Usuarios_Desactivar."""
    try:
        ejecutar_accion(Sp.USUARIOS_DESACTIVAR, {"id_usuario": id_usuario})
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def cambiar_password(id_usuario: int, password_hash: str) -> None:
    """Ejecuta dbo.sp_Usuarios_CambiarPassword."""
    try:
        ejecutar_accion(
            Sp.USUARIOS_CAMBIAR_PASSWORD,
            {"id_usuario": id_usuario, "password_hash": password_hash},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def listar_roles(id_usuario: int) -> list[dict]:
    """Ejecuta dbo.sp_Usuarios_ListarRoles."""
    return ejecutar_lista(Sp.USUARIOS_LISTAR_ROLES, {"id_usuario": id_usuario})


def listar_permisos(id_usuario: int) -> list[dict]:
    """Ejecuta dbo.sp_Usuarios_ListarPermisos."""
    return ejecutar_lista(
        Sp.USUARIOS_LISTAR_PERMISOS, {"id_usuario": id_usuario}
    )


def asignar_rol(id_usuario: int, id_rol: int) -> None:
    """Ejecuta dbo.sp_Usuarios_AsignarRol."""
    try:
        ejecutar_accion(
            Sp.USUARIOS_ASIGNAR_ROL,
            {"id_usuario": id_usuario, "id_rol": id_rol},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def quitar_rol(id_usuario: int, id_rol: int) -> None:
    """Ejecuta dbo.sp_Usuarios_QuitarRol."""
    try:
        ejecutar_accion(
            Sp.USUARIOS_QUITAR_ROL,
            {"id_usuario": id_usuario, "id_rol": id_rol},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error
