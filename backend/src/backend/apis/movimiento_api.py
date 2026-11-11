"""Endpoints HTTP de entradas, salidas y movimientos."""

from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Response, status

from backend.dependencies import requiere_permiso
from backend.schemas.auth import UsuarioAutenticado
from backend.schemas.movimiento import (
    EntradaCrear,
    EntradaRegistrada,
    MotivoEntrada,
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

LECTURA = Depends(requiere_permiso("movimientos:leer"))
ENTRADA = requiere_permiso("movimientos:entrada")
SALIDA = requiere_permiso("movimientos:salida")


@router.get(
    "/motivos-entrada",
    response_model=list[str],
    dependencies=[LECTURA],
)
def motivos_entrada() -> list[str]:
    """Catálogo cerrado de motivos de entrada admitidos por la API."""
    return [motivo.value for motivo in MotivoEntrada]


@router.get("", response_model=list[MovimientoListado], dependencies=[LECTURA])
def listar(
    response: Response,
    id_producto: Annotated[int | None, Query(gt=0)] = None,
    tipo_movimiento: Annotated[Literal["ENTRADA", "SALIDA"] | None, Query()] = None,
    id_area: Annotated[int | None, Query(gt=0)] = None,
    desde: Annotated[date | None, Query()] = None,
    hasta: Annotated[date | None, Query()] = None,
    busqueda: Annotated[str | None, Query(max_length=150)] = None,
    pagina: Annotated[int | None, Query(ge=1)] = None,
    tamano: Annotated[int | None, Query(ge=1, le=100)] = None,
) -> list[MovimientoListado]:
    """Lista movimientos usando dbo.sp_Movimientos_Listar.

    Sin ``pagina``/``tamano`` devuelve todos los resultados. Con paginación,
    ``X-Total-Count`` informa el total de coincidencias de los filtros.
    """
    filas, total = listar_movimientos(
        id_producto,
        tipo_movimiento,
        id_area,
        desde,
        hasta,
        busqueda,
        pagina,
        tamano,
    )
    response.headers["X-Total-Count"] = str(total)
    return filas


@router.post(
    "/entradas", response_model=EntradaRegistrada, status_code=status.HTTP_201_CREATED
)
def crear_entrada(
    datos: EntradaCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(ENTRADA)],
) -> EntradaRegistrada:
    """Registra una entrada usando dbo.sp_Movimientos_RegistrarEntrada."""
    return registrar_entrada(datos, usuario.id_usuario)


@router.post(
    "/salidas", response_model=SalidaRegistrada, status_code=status.HTTP_201_CREATED
)
def crear_salida(
    datos: SalidaCrear,
    usuario: Annotated[UsuarioAutenticado, Depends(SALIDA)],
) -> SalidaRegistrada:
    """Registra una salida usando dbo.sp_Movimientos_RegistrarSalida."""
    return registrar_salida(datos, usuario.id_usuario)
