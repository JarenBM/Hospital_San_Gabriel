"""Modelos de áreas hospitalarias."""

from typing import Annotated

from pydantic import BaseModel, StringConstraints

NombreArea = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)
]


class Area(BaseModel):
    """Fila devuelta por dbo.sp_Areas_Listar y dbo.sp_Areas_Obtener."""

    id_area: int
    nombre: str
    activo: bool


class AreaCrear(BaseModel):
    """Datos para dbo.sp_Areas_Crear."""

    nombre: NombreArea


class AreaActualizar(BaseModel):
    """Datos para dbo.sp_Areas_Actualizar. ``activo`` None conserva el estado."""

    nombre: NombreArea
    activo: bool | None = None
