"""Modelos de categorías intercambiados por la API."""

from typing import Annotated

from pydantic import BaseModel, StringConstraints

# Límites reales de las columnas: NVARCHAR(100) y NVARCHAR(255).
NombreCategoria = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)
]
DescripcionCategoria = Annotated[
    str, StringConstraints(strip_whitespace=True, max_length=255)
]


class Categoria(BaseModel):
    """Fila devuelta por dbo.sp_Categoria_Listar y dbo.sp_Categoria_Obtener."""

    id_categoria: int
    nombre: str
    descripcion: str | None = None
    activo: bool


class CategoriaCrear(BaseModel):
    """Datos para dbo.sp_Categoria_Crear."""

    nombre: NombreCategoria
    descripcion: DescripcionCategoria | None = None


class CategoriaActualizar(BaseModel):
    """Datos para dbo.sp_Categoria_Actualizar.

    Si ``activo`` se omite, el estado actual de la categoría no cambia.
    """

    nombre: NombreCategoria
    descripcion: DescripcionCategoria | None = None
    activo: bool | None = None
