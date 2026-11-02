"""Endpoints HTTP de roles y permisos."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.rol import (
    Permiso,
    Rol,
    RolActualizar,
    RolCrear,
    RolPermisos,
)
from backend.services.rol_service import (
    actualizar_rol,
    asignar_permiso,
    crear_rol,
    desactivar_rol,
    listar_permisos_rol,
    listar_roles,
    obtener_rol,
    quitar_permiso,
    sincronizar_permisos,
)

router = APIRouter(prefix="/api/roles", tags=["Roles"])

GESTION = requiere_permiso("roles:gestionar")


@router.get("", response_model=list[Rol])
def listar(
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
    solo_activos: Annotated[bool | None, Query()] = None,
) -> list[Rol]:
    """Lista roles usando dbo.sp_Roles_Listar."""
    return listar_roles(solo_activos)


@router.get("/{id_rol}", response_model=Rol)
def obtener(
    id_rol: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Rol:
    """Obtiene un rol usando dbo.sp_Roles_Obtener."""
    return obtener_rol(id_rol)


@router.post("", response_model=Rol, status_code=status.HTTP_201_CREATED)
def crear(
    datos: RolCrear,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Rol:
    """Crea un rol usando dbo.sp_Roles_Crear."""
    return crear_rol(datos, actor.id_usuario)


@router.put("/{id_rol}", response_model=Rol)
def actualizar(
    id_rol: int,
    datos: RolActualizar,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Rol:
    """Actualiza un rol usando dbo.sp_Roles_Actualizar."""
    return actualizar_rol(id_rol, datos, actor.id_usuario)


@router.delete("/{id_rol}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar(
    id_rol: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Desactiva un rol usando dbo.sp_Roles_Desactivar."""
    desactivar_rol(id_rol, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{id_rol}/permisos", response_model=list[Permiso])
def permisos(
    id_rol: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> list[Permiso]:
    """Lista los permisos de un rol."""
    return listar_permisos_rol(id_rol)


@router.put("/{id_rol}/permisos", response_model=dict)
def sincronizar(
    id_rol: int,
    datos: RolPermisos,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> dict:
    """Reemplaza el conjunto completo de permisos de un rol."""
    total = sincronizar_permisos(id_rol, datos, actor.id_usuario)
    return {"total": total}


@router.post("/{id_rol}/permisos/{id_permiso}", status_code=status.HTTP_204_NO_CONTENT)
def asignar(
    id_rol: int,
    id_permiso: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Asigna un permiso puntual a un rol."""
    asignar_permiso(id_rol, id_permiso, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{id_rol}/permisos/{id_permiso}", status_code=status.HTTP_204_NO_CONTENT
)
def quitar(
    id_rol: int,
    id_permiso: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Response:
    """Quita un permiso puntual a un rol."""
    quitar_permiso(id_rol, id_permiso, actor.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
