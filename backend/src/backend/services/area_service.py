"""Lógica de negocio de áreas hospitalarias."""

from backend.repositories.area_repository import listar_areas as listar_areas_repositorio
from backend.schemas.area import Area


def listar_areas() -> list[Area]:
    """Devuelve todas las áreas hospitalarias, activas e inactivas."""
    filas = listar_areas_repositorio()
    return [Area(**fila) for fila in filas]
