"""Endpoints HTTP del catálogo de permisos."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.rol import Permiso
from backend.services.rol_service import listar_permisos, obtener_permiso

router = APIRouter(prefix="/api/permisos", tags=["Permisos"])

GESTION = requiere_permiso("roles:gestionar")


@router.get("", response_model=list[Permiso])
def listar(
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
    modulo: Annotated[str | None, Query(max_length=50)] = None,
) -> list[Permiso]:
    """Lista el catálogo de permisos usando dbo.sp_Permisos_Listar."""
    return listar_permisos(modulo)


@router.get("/{id_permiso}", response_model=Permiso)
def obtener(
    id_permiso: int,
    actor: Annotated[UsuarioAutenticado, Depends(GESTION)],
) -> Permiso:
    """Obtiene un permiso usando dbo.sp_Permisos_Obtener."""
    return obtener_permiso(id_permiso)
