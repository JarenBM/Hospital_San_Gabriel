"""Endpoints HTTP de gestión de usuarios."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.rol import PermisoAsignado, Rol
from backend.schemas.usuario import (
    Usuario,
    UsuarioActualizar,
    UsuarioCrear,
    UsuarioPassword,
    UsuarioRol,
)
from backend.services.usuario_service import (
    actualizar_usuario,
    asignar_rol,
    cambiar_password,
    crear_usuario,
    desactivar_usuario,
    listar_permisos,
    listar_roles,
    listar_usuarios,
    obtener_usuario,
    quitar_rol,
)

router = APIRouter(prefix="/api/usuarios", tags=["Usuarios"])

GESTION = requiere_permiso("usuarios:gestionar")


@router.get("", response_model=list[Usuario])
def listar(
    response: Response,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
    busqueda: Annotated[str | None, Query(max_length=150)] = None,
    id_rol: Annotated[int | None, Query(gt=0)] = None,
    solo_activos: Annotated[bool | None, Query()] = None,
    pagina: Annotated[int | None, Query(ge=1)] = None,
    tamano: Annotated[int | None, Query(ge=1, le=100)] = None,
) -> list[Usuario]:
    """Lista usuarios usando dbo.sp_Usuarios_Listar.

    Sin ``pagina``/``tamano`` devuelve todos los resultados. Con paginación,
    ``X-Total-Count`` informa el total de coincidencias de los filtros.
    """
    filas, total = listar_usuarios(
        busqueda, id_rol, solo_activos, pagina, tamano
    )
    response.headers["X-Total-Count"] = str(total)
    return filas


@router.get("/{id_usuario}", response_model=Usuario)
def obtener(
    id_usuario: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Usuario:
    """Obtiene un usuario usando dbo.sp_Usuarios_Obtener."""
    return obtener_usuario(id_usuario)


@router.post("", response_model=Usuario, status_code=status.HTTP_201_CREATED)
def crear(
    datos: UsuarioCrear,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Usuario:
    """Crea un usuario usando dbo.sp_Usuarios_Crear."""
    return crear_usuario(datos, actor.id_usuario)


@router.put("/{id_usuario}", response_model=Usuario)
def actualizar(
    id_usuario: int,
    datos: UsuarioActualizar,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Usuario:
    """Actualiza un usuario usando dbo.sp_Usuarios_Actualizar."""
    return actualizar_usuario(id_usuario, datos, actor.id_usuario)


@router.delete("/{id_usuario}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar(
    id_usuario: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Desactiva un usuario usando dbo.sp_Usuarios_Desactivar."""
    desactivar_usuario(id_usuario, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put("/{id_usuario}/password", status_code=status.HTTP_204_NO_CONTENT)
def cambiar_contrasena(
    id_usuario: int,
    datos: UsuarioPassword,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Reemplaza la contraseña de un usuario (reset administrativo)."""
    cambiar_password(id_usuario, datos.password, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{id_usuario}/roles", response_model=list[Rol])
def roles(
    id_usuario: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> list[Rol]:
    """Lista los roles asignados a un usuario."""
    return listar_roles(id_usuario)


@router.get("/{id_usuario}/permisos", response_model=list[PermisoAsignado])
def permisos(
    id_usuario: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> list[PermisoAsignado]:
    """Lista los permisos efectivos de un usuario."""
    return listar_permisos(id_usuario)


@router.post("/{id_usuario}/roles", status_code=status.HTTP_204_NO_CONTENT)
def asignar(
    id_usuario: int,
    datos: UsuarioRol,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Asigna un rol a un usuario."""
    asignar_rol(id_usuario, datos.id_rol, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{id_usuario}/roles/{id_rol}", status_code=status.HTTP_204_NO_CONTENT
)
def quitar(
    id_usuario: int,
    id_rol: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Quita un rol a un usuario."""
    quitar_rol(id_usuario, id_rol, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
