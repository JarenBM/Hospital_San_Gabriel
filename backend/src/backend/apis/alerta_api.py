"""Endpoints HTTP de alertas de inventario (solo lectura)."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query

from backend.schemas.alerta import LoteAlerta, ProductoStockBajo, ResumenInventario
from backend.services.alerta_service import (
    listar_por_vencer,
    listar_stock_bajo,
    listar_vencidos,
    obtener_resumen,
)

router = APIRouter(prefix="/api/alertas", tags=["Alertas"])


@router.get("/stock-bajo", response_model=list[ProductoStockBajo])
def stock_bajo() -> list[ProductoStockBajo]:
    """Productos con stock bajo usando dbo.sp_Producto_StockBajo."""
    return listar_stock_bajo()


@router.get("/por-vencer", response_model=list[LoteAlerta])
def por_vencer(
    dias: Annotated[int, Query(ge=0, le=3650)] = 30,
) -> list[LoteAlerta]:
    """Lotes próximos a vencer usando dbo.sp_Lote_Vencimientos."""
    return listar_por_vencer(dias)


@router.get("/vencidos", response_model=list[LoteAlerta])
def vencidos() -> list[LoteAlerta]:
    """Lotes vencidos con existencias, incluidos los más antiguos."""
    return listar_vencidos()


@router.get("/resumen", response_model=ResumenInventario)
def resumen(
    desde: Annotated[date | None, Query()] = None,
    hasta: Annotated[date | None, Query()] = None,
) -> ResumenInventario:
    """Resumen de inventario usando dbo.sp_Dashboard_Resumen."""
    return obtener_resumen(desde, hasta)
