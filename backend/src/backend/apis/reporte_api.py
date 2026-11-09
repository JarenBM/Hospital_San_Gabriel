"""Endpoints HTTP de reportes de inventario."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.reporte import ConsumoArea, MayorSalida, StockValorizado
from backend.services.reporte_service import (
    consumo_por_area,
    mayores_salidas,
    stock_valorizado,
)

router = APIRouter(prefix="/api/reportes", tags=["Reportes"])

LECTURA = requiere_permiso("reportes:leer")


@router.get("/mayores-salidas", response_model=list[MayorSalida])
def mayores(
    desde: Annotated[date, Query()],
    hasta: Annotated[date, Query()],
    actor: Annotated[UsuarioAutenticado, Depends(LECTURA)],
    top: Annotated[int, Query(gt=0, le=100)] = 10,
) -> list[MayorSalida]:
    """Productos con más salidas en el rango usando dbo.sp_Reportes_MayoresSalidas."""
    return mayores_salidas(desde, hasta, top)


@router.get("/consumo-por-area", response_model=list[ConsumoArea])
def consumo(
    desde: Annotated[date, Query()],
    hasta: Annotated[date, Query()],
    actor: Annotated[UsuarioAutenticado, Depends(LECTURA)],
) -> list[ConsumoArea]:
    """Consumo por área usando dbo.sp_Reportes_ConsumoPorArea."""
    return consumo_por_area(desde, hasta)


@router.get("/stock-valorizado", response_model=list[StockValorizado])
def stock(
    actor: Annotated[UsuarioAutenticado, Depends(LECTURA)],
) -> list[StockValorizado]:
    """Inventario valuado usando dbo.sp_Reportes_StockValorizado."""
    return stock_valorizado()
