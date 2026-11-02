"""Lógica de negocio de gestión de usuarios."""

from backend.errors import UsuarioNoEncontrado
from backend.repositories import auditoria_repository
from backend.repositories.usuario_repository import (
    actualizar_usuario as actualizar_usuario_repositorio,
    asignar_rol as asignar_rol_repositorio,
    cambiar_password as cambiar_password_repositorio,
    crear_usuario as crear_usuario_repositorio,
    desactivar_usuario as desactivar_usuario_repositorio,
    listar_permisos as listar_permisos_repositorio,
    listar_roles as listar_roles_repositorio,
    listar_usuarios as listar_usuarios_repositorio,
    obtener_usuario as obtener_usuario_repositorio,
    quitar_rol as quitar_rol_repositorio,
)
from backend.schemas.rol import PermisoAsignado, Rol
from backend.schemas.usuario import (
    Usuario,
    UsuarioActualizar,
    UsuarioCrear,
)
from backend.security import hashear_password


def listar_usuarios(
    busqueda: str | None = None,
    id_rol: int | None = None,
    solo_activos: bool | None = None,
) -> list[Usuario]:
    """Devuelve los usuarios con el resumen de sus roles."""
    filas = listar_usuarios_repositorio(busqueda, id_rol, solo_activos)
    return [Usuario(**fila) for fila in filas]


def obtener_usuario(id_usuario: int) -> Usuario:
    """Devuelve un usuario o lanza UsuarioNoEncontrado."""
    fila = obtener_usuario_repositorio(id_usuario)
    if fila is None:
        raise UsuarioNoEncontrado(f"El usuario {id_usuario} no existe")
    return Usuario(**fila)


def crear_usuario(datos: UsuarioCrear, id_actor: int | None = None) -> Usuario:
    """Crea un usuario con contraseña Argon2id."""
    id_usuario = crear_usuario_repositorio(
        datos.nombre,
        datos.email,
        hashear_password(datos.password),
        datos.id_rol,
    )
    auditoria_repository.registrar(
        id_actor, "CREAR", "usuarios", id_usuario, f"Correo: {datos.email}"
    )
    return obtener_usuario(id_usuario)


def actualizar_usuario(
    id_usuario: int,
    datos: UsuarioActualizar,
    id_actor: int | None = None,
) -> Usuario:
    """Actualiza nombre, correo y, opcionalmente, el estado activo."""
    actualizar_usuario_repositorio(
        id_usuario, datos.nombre, datos.email, datos.activo
    )
    auditoria_repository.registrar(
        id_actor, "ACTUALIZAR", "usuarios", id_usuario, f"Correo: {datos.email}"
    )
    return obtener_usuario(id_usuario)


def desactivar_usuario(id_usuario: int, id_actor: int | None = None) -> None:
    """Desactiva un usuario (el SP impide dejar sin administradores)."""
    desactivar_usuario_repositorio(id_usuario)
    auditoria_repository.registrar(
        id_actor, "DESACTIVAR", "usuarios", id_usuario
    )


def cambiar_password(
    id_usuario: int, password: str, id_actor: int | None = None
) -> None:
    """Reemplaza la contraseña por un hash Argon2id nuevo."""
    cambiar_password_repositorio(id_usuario, hashear_password(password))
    auditoria_repository.registrar(
        id_actor, "CAMBIAR_PASSWORD", "usuarios", id_usuario
    )


def listar_roles(id_usuario: int) -> list[Rol]:
    """Roles asignados a un usuario."""
    obtener_usuario(id_usuario)
    return [Rol(**fila) for fila in listar_roles_repositorio(id_usuario)]


def listar_permisos(id_usuario: int) -> list[PermisoAsignado]:
    """Permisos efectivos de un usuario (solo roles activos)."""
    obtener_usuario(id_usuario)
    return [
        PermisoAsignado(**fila)
        for fila in listar_permisos_repositorio(id_usuario)
    ]


def asignar_rol(
    id_usuario: int, id_rol: int, id_actor: int | None = None
) -> None:
    """Asigna un rol al usuario."""
    asignar_rol_repositorio(id_usuario, id_rol)
    auditoria_repository.registrar(
        id_actor, "ASIGNAR_ROL", "usuarios", id_usuario, f"Rol: {id_rol}"
    )


def quitar_rol(
    id_usuario: int, id_rol: int, id_actor: int | None = None
) -> None:
    """Quita un rol al usuario."""
    quitar_rol_repositorio(id_usuario, id_rol)
    auditoria_repository.registrar(
        id_actor, "QUITAR_ROL", "usuarios", id_usuario, f"Rol: {id_rol}"
    )
