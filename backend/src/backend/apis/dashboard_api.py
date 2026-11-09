"""Endpoint HTTP del dashboard."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from backend.dependencies import requiere_permiso
from backend.schemas.alerta import ResumenInventario
from backend.schemas.auth import UsuarioAutenticado
from backend.services.alerta_service import obtener_resumen

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])

LECTURA = requiere_permiso("dashboard:leer")


@router.get("/resumen", response_model=ResumenInventario)
def resumen(
    actor: Annotated[UsuarioAutenticado, Depends(LECTURA)],
    desde: Annotated[date | None, Query()] = None,
    hasta: Annotated[date | None, Query()] = None,
) -> ResumenInventario:
    """Resumen de inventario usando dbo.sp_Dashboard_Resumen."""
    return obtener_resumen(desde, hasta)
