"""Endpoints HTTP de categorías."""

from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.categoria import Categoria, CategoriaActualizar, CategoriaCrear
from backend.services.categoria_service import (
    actualizar_categoria,
    crear_categoria,
    desactivar_categoria,
    listar_categorias,
    obtener_categoria,
)

router = APIRouter(prefix="/api/categorias", tags=["Categorías"])

LECTURA = Depends(requiere_permiso("categorias:leer"))
ESCRITURA = requiere_permiso("categorias:escribir")


@router.get("", response_model=list[Categoria], dependencies=[LECTURA])
def listar() -> list[Categoria]:
    """Lista las categorías usando dbo.sp_Categorias_Listar."""
    return listar_categorias()


@router.get("/{id_categoria}", response_model=Categoria, dependencies=[LECTURA])
def obtener(id_categoria: int) -> Categoria:
    """Obtiene una categoría por ID usando dbo.sp_Categorias_Obtener."""
    return obtener_categoria(id_categoria)


@router.post("", response_model=Categoria, status_code=status.HTTP_201_CREATED)
def crear(
    datos: CategoriaCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Categoria:
    """Registra una categoría usando dbo.sp_Categorias_Crear."""
    return crear_categoria(datos.nombre, datos.descripcion, usuario.id_usuario)


@router.put("/{id_categoria}", response_model=Categoria)
def actualizar(
    id_categoria: int,
    datos: CategoriaActualizar,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Categoria:
    """Actualiza una categoría usando dbo.sp_Categorias_Actualizar."""
    return actualizar_categoria(
        id_categoria,
        datos.nombre,
        datos.descripcion,
        datos.activo,
        usuario.id_usuario,
    )


@router.delete("/{id_categoria}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar(
    id_categoria: int,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Response:
    """Desactiva una categoría usando dbo.sp_Categorias_Desactivar."""
    desactivar_categoria(id_categoria, usuario.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
