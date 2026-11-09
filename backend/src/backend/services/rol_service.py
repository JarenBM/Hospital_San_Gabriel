"""Lógica de negocio de roles y permisos."""

import json

from backend.errors import PermisoNoEncontrado, RolNoEncontrado
from backend.repositories import auditoria_repository
from backend.repositories.rol_repository import (
    actualizar_rol as actualizar_rol_repositorio,
    asignar_permiso as asignar_permiso_repositorio,
    crear_rol as crear_rol_repositorio,
    desactivar_rol as desactivar_rol_repositorio,
    listar_permisos as listar_permisos_repositorio,
    listar_permisos_rol as listar_permisos_rol_repositorio,
    listar_roles as listar_roles_repositorio,
    obtener_permiso as obtener_permiso_repositorio,
    obtener_rol as obtener_rol_repositorio,
    quitar_permiso as quitar_permiso_repositorio,
    sincronizar_permisos as sincronizar_permisos_repositorio,
)
from backend.schemas.rol import (
    Permiso,
    Rol,
    RolActualizar,
    RolCrear,
    RolPermisos,
)


def listar_roles(solo_activos: bool | None = None) -> list[Rol]:
    """Devuelve todos los roles."""
    return [Rol(**fila) for fila in listar_roles_repositorio(solo_activos)]


def obtener_rol(id_rol: int) -> Rol:
    """Devuelve un rol o lanza RolNoEncontrado."""
    fila = obtener_rol_repositorio(id_rol)
    if fila is None:
        raise RolNoEncontrado(f"El rol {id_rol} no existe")
    return Rol(**fila)


def crear_rol(datos: RolCrear, id_actor: int | None = None) -> Rol:
    """Crea un rol."""
    id_rol = crear_rol_repositorio(datos.nombre, datos.descripcion)
    auditoria_repository.registrar(
        id_actor, "CREAR", "roles", id_rol, f"Rol: {datos.nombre}"
    )
    return obtener_rol(id_rol)


def actualizar_rol(
    id_rol: int, datos: RolActualizar, id_actor: int | None = None
) -> Rol:
    """Actualiza un rol."""
    actualizar_rol_repositorio(
        id_rol, datos.nombre, datos.descripcion, datos.activo
    )
    auditoria_repository.registrar(
        id_actor, "ACTUALIZAR", "roles", id_rol, f"Rol: {datos.nombre}"
    )
    return obtener_rol(id_rol)


def desactivar_rol(id_rol: int, id_actor: int | None = None) -> None:
    """Desactiva un rol (ADMINISTRADOR está protegido por el SP)."""
    desactivar_rol_repositorio(id_rol)
    auditoria_repository.registrar(id_actor, "DESACTIVAR", "roles", id_rol)


def listar_permisos_rol(id_rol: int) -> list[Permiso]:
    """Permisos asignados a un rol."""
    obtener_rol(id_rol)
    return [Permiso(**fila) for fila in listar_permisos_rol_repositorio(id_rol)]


def listar_permisos(modulo: str | None = None) -> list[Permiso]:
    """Catálogo completo de permisos."""
    return [Permiso(**fila) for fila in listar_permisos_repositorio(modulo)]


def obtener_permiso(id_permiso: int) -> Permiso:
    """Devuelve un permiso del catálogo."""
    fila = obtener_permiso_repositorio(id_permiso)
    if fila is None:
        raise PermisoNoEncontrado(f"El permiso {id_permiso} no existe")
    return Permiso(**fila)


def asignar_permiso(
    id_rol: int, id_permiso: int, id_actor: int | None = None
) -> None:
    """Asigna un permiso a un rol."""
    asignar_permiso_repositorio(id_rol, id_permiso)
    auditoria_repository.registrar(
        id_actor,
        "ASIGNAR_PERMISO",
        "roles",
        id_rol,
        f"Permiso: {id_permiso}",
    )


def quitar_permiso(
    id_rol: int, id_permiso: int, id_actor: int | None = None
) -> None:
    """Quita un permiso a un rol."""
    quitar_permiso_repositorio(id_rol, id_permiso)
    auditoria_repository.registrar(
        id_actor,
        "QUITAR_PERMISO",
        "roles",
        id_rol,
        f"Permiso: {id_permiso}",
    )


def sincronizar_permisos(
    id_rol: int, datos: RolPermisos, id_actor: int | None = None
) -> int:
    """Reemplaza el conjunto de permisos de un rol."""
    permisos_json = json.dumps(datos.permisos, ensure_ascii=False)
    total = sincronizar_permisos_repositorio(id_rol, permisos_json)
    auditoria_repository.registrar(
        id_actor,
        "SINCRONIZAR_PERMISOS",
        "roles",
        id_rol,
        f"Permisos aplicados: {total}",
    )
    return total
