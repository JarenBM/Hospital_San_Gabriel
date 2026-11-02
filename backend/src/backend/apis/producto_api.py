"""Endpoints HTTP de productos."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from backend.dependencies import obtener_usuario_actual
from backend.schemas.producto import (
    Producto,
    ProductoActualizar,
    ProductoCrear,
    ProductoListado,
)
from backend.services.producto_service import (
    actualizar_producto,
    crear_producto,
    desactivar_producto,
    listar_productos,
    obtener_producto,
)

router = APIRouter(prefix="/api/productos", tags=["Productos"])


@router.get("", response_model=list[ProductoListado])
def listar(
    busqueda: Annotated[str | None, Query(max_length=150)] = None,
    id_categoria: Annotated[int | None, Query(gt=0)] = None,
    solo_activos: Annotated[bool | None, Query()] = None,
) -> list[ProductoListado]:
    """Lista productos usando dbo.sp_Producto_Listar."""
    return listar_productos(busqueda, id_categoria, solo_activos)


@router.get("/{id_producto}", response_model=Producto)
def obtener(id_producto: int) -> Producto:
    """Obtiene un producto por ID usando dbo.sp_Producto_Obtener."""
    return obtener_producto(id_producto)


@router.post(
    "",
    response_model=Producto,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(obtener_usuario_actual)],
)
def crear(datos: ProductoCrear) -> Producto:
    """Registra un producto usando dbo.sp_Producto_Crear."""
    return crear_producto(datos)


@router.put(
    "/{id_producto}",
    response_model=Producto,
    dependencies=[Depends(obtener_usuario_actual)],
)
def actualizar(id_producto: int, datos: ProductoActualizar) -> Producto:
    """Actualiza un producto usando dbo.sp_Producto_Actualizar."""
    return actualizar_producto(id_producto, datos)


@router.delete(
    "/{id_producto}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(obtener_usuario_actual)],
)
def desactivar(id_producto: int) -> Response:
    """Desactiva un producto usando dbo.sp_Producto_Desactivar."""
    desactivar_producto(id_producto)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
