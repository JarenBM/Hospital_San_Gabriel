"""Endpoints HTTP de áreas hospitalarias."""

from fastapi import APIRouter

from backend.schemas.area import Area
from backend.services.area_service import listar_areas

router = APIRouter(prefix="/api/areas", tags=["Áreas"])


@router.get("", response_model=list[Area])
def listar() -> list[Area]:
    """Lista las áreas hospitalarias usando dbo.sp_Area_Listar."""
    return listar_areas()
