"""Modelos de áreas hospitalarias."""

from pydantic import BaseModel


class Area(BaseModel):
    """Fila devuelta por dbo.sp_Area_Listar."""

    id_area: int
    nombre: str
    activo: bool
