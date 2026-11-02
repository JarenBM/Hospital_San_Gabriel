"""Endpoints HTTP de áreas hospitalarias."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from backend.dependencies import requiere_permiso
from backend.schemas.area import Area, AreaActualizar, AreaCrear
from backend.schemas.auth import UsuarioAutenticado
from backend.services.area_service import (
    actualizar_area,
    crear_area,
    desactivar_area,
    listar_areas,
    obtener_area,
)

router = APIRouter(prefix="/api/areas", tags=["Áreas"])

LECTURA = Depends(requiere_permiso("areas:leer"))
ESCRITURA = requiere_permiso("areas:escribir")


@router.get("", response_model=list[Area], dependencies=[LECTURA])
def listar(
    solo_activos: Annotated[bool | None, Query()] = None,
) -> list[Area]:
    """Lista las áreas hospitalarias usando dbo.sp_Areas_Listar."""
    return listar_areas(solo_activos)


@router.get("/{id_area}", response_model=Area, dependencies=[LECTURA])
def obtener(id_area: int) -> Area:
    """Obtiene un área por ID usando dbo.sp_Areas_Obtener."""
    return obtener_area(id_area)


@router.post("", response_model=Area, status_code=status.HTTP_201_CREATED)
def crear(
    datos: AreaCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Area:
    """Crea un área usando dbo.sp_Areas_Crear."""
    return crear_area(datos, usuario.id_usuario)


@router.put("/{id_area}", response_model=Area)
def actualizar(
    id_area: int,
    datos: AreaActualizar,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Area:
    """Actualiza un área usando dbo.sp_Areas_Actualizar."""
    return actualizar_area(id_area, datos, usuario.id_usuario)


@router.delete("/{id_area}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar(
    id_area: int,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Response:
    """Desactiva un área usando dbo.sp_Areas_Desactivar."""
    desactivar_area(id_area, usuario.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
