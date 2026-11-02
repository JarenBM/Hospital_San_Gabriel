"""Endpoints HTTP de lotes."""

from fastapi import APIRouter

from backend.schemas.lote import Lote
from backend.services.lote_service import listar_lotes_por_producto

router = APIRouter(prefix="/api/productos", tags=["Lotes"])


@router.get("/{id_producto}/lotes", response_model=list[Lote])
def listar(id_producto: int) -> list[Lote]:
    """Lista los lotes de un producto usando dbo.sp_Lote_ListarPorProducto."""
    return listar_lotes_por_producto(id_producto)
