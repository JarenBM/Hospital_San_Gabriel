"""Endpoints HTTP de categorías."""

from fastapi import APIRouter, Depends, Response, status

from backend.dependencies import obtener_usuario_actual
from backend.schemas.categoria import Categoria, CategoriaActualizar, CategoriaCrear
from backend.services.categoria_service import (
    actualizar_categoria,
    crear_categoria,
    desactivar_categoria,
    listar_categorias,
    obtener_categoria,
)

router = APIRouter(prefix="/api/categorias", tags=["Categorías"])


@router.get("", response_model=list[Categoria])
def listar() -> list[Categoria]:
    """Lista las categorías usando dbo.sp_Categoria_Listar."""
    return listar_categorias()


@router.get("/{id_categoria}", response_model=Categoria)
def obtener(id_categoria: int) -> Categoria:
    """Obtiene una categoría por ID usando dbo.sp_Categoria_Obtener."""
    return obtener_categoria(id_categoria)


@router.post(
    "",
    response_model=Categoria,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(obtener_usuario_actual)],
)
def crear(datos: CategoriaCrear) -> Categoria:
    """Registra una categoría usando dbo.sp_Categoria_Crear."""
    return crear_categoria(datos.nombre, datos.descripcion)


@router.put(
    "/{id_categoria}",
    response_model=Categoria,
    dependencies=[Depends(obtener_usuario_actual)],
)
def actualizar(id_categoria: int, datos: CategoriaActualizar) -> Categoria:
    """Actualiza una categoría usando dbo.sp_Categoria_Actualizar."""
    return actualizar_categoria(
        id_categoria, datos.nombre, datos.descripcion, datos.activo
    )


@router.delete(
    "/{id_categoria}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(obtener_usuario_actual)],
)
def desactivar(id_categoria: int) -> Response:
    """Desactiva una categoría usando dbo.sp_Categoria_Desactivar."""
    desactivar_categoria(id_categoria)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
