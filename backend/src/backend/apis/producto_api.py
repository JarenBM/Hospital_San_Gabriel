"""Endpoints HTTP de productos."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
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

LECTURA = Depends(requiere_permiso("productos:leer"))
ESCRITURA = requiere_permiso("productos:escribir")


@router.get("", response_model=list[ProductoListado], dependencies=[LECTURA])
def listar(
    response: Response,
    busqueda: Annotated[str | None, Query(max_length=150)] = None,
    id_categoria: Annotated[int | None, Query(gt=0)] = None,
    solo_activos: Annotated[bool | None, Query()] = None,
    pagina: Annotated[int | None, Query(ge=1)] = None,
    tamano: Annotated[int | None, Query(ge=1, le=100)] = None,
) -> list[ProductoListado]:
    """Lista productos usando dbo.sp_Productos_Listar.

    Sin ``pagina``/``tamano`` devuelve todos los resultados. Con paginación,
    ``X-Total-Count`` informa el total de coincidencias de los filtros.
    """
    filas, total = listar_productos(
        busqueda, id_categoria, solo_activos, pagina, tamano
    )
    response.headers["X-Total-Count"] = str(total)
    return filas


@router.get("/{id_producto}", response_model=Producto, dependencies=[LECTURA])
def obtener(id_producto: int) -> Producto:
    """Obtiene un producto por ID usando dbo.sp_Productos_Obtener."""
    return obtener_producto(id_producto)


@router.post("", response_model=Producto, status_code=status.HTTP_201_CREATED)
def crear(
    datos: ProductoCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Producto:
    """Registra un producto usando dbo.sp_Productos_Crear."""
    return crear_producto(datos, usuario.id_usuario)


@router.put("/{id_producto}", response_model=Producto)
def actualizar(
    id_producto: int,
    datos: ProductoActualizar,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Producto:
    """Actualiza un producto usando dbo.sp_Productos_Actualizar."""
    return actualizar_producto(id_producto, datos, usuario.id_usuario)


@router.delete("/{id_producto}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar(
    id_producto: int,
    usuario: Annotated[UsuarioAutenticado, Depends(ESCRITURA)],
) -> Response:
    """Desactiva un producto usando dbo.sp_Productos_Desactivar."""
    desactivar_producto(id_producto, usuario.id_usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
