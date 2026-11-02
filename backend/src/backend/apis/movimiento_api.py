"""Endpoints HTTP de entradas, salidas y movimientos."""

from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, status

from backend.dependencies import obtener_usuario_actual
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.movimiento import (
    EntradaCrear,
    EntradaRegistrada,
    MovimientoListado,
    SalidaCrear,
    SalidaRegistrada,
)
from backend.services.movimiento_service import (
    listar_movimientos,
    registrar_entrada,
    registrar_salida,
)

router = APIRouter(prefix="/api/movimientos", tags=["Movimientos"])


@router.get("", response_model=list[MovimientoListado])
def listar(
    id_producto: Annotated[int | None, Query(gt=0)] = None,
    tipo_movimiento: Annotated[Literal["ENTRADA", "SALIDA"] | None, Query()] = None,
    id_area: Annotated[int | None, Query(gt=0)] = None,
    desde: Annotated[date | None, Query()] = None,
    hasta: Annotated[date | None, Query()] = None,
) -> list[MovimientoListado]:
    """Lista movimientos usando dbo.sp_Movimiento_Listar."""
    return listar_movimientos(id_producto, tipo_movimiento, id_area, desde, hasta)


@router.post(
    "/entradas", response_model=EntradaRegistrada, status_code=status.HTTP_201_CREATED
)
def crear_entrada(
    datos: EntradaCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(obtener_usuario_actual)],
) -> EntradaRegistrada:
    """Registra una entrada usando dbo.sp_Entrada_Registrar."""
    return registrar_entrada(datos, usuario.id_usuario)


@router.post(
    "/salidas", response_model=SalidaRegistrada, status_code=status.HTTP_201_CREATED
)
def crear_salida(
    datos: SalidaCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(obtener_usuario_actual)],
) -> SalidaRegistrada:
    """Registra una salida usando dbo.sp_Salida_Registrar."""
    return registrar_salida(datos, usuario.id_usuario)
