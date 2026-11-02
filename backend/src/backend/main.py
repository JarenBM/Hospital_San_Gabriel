"""Punto de entrada de la API SIGIH.

Inicio: uv run uvicorn backend.main:app
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from backend.apis.alerta_api import router as alertas_router
from backend.apis.area_api import router as areas_router
from backend.apis.auth_api import router as auth_router
from backend.apis.categoria_api import router as categorias_router
from backend.apis.dashboard_api import router as dashboard_router
from backend.apis.lote_api import router as lotes_router
from backend.apis.movimiento_api import router as movimientos_router
from backend.apis.permiso_api import router as permisos_router
from backend.apis.producto_api import router as productos_router
from backend.apis.reporte_api import router as reportes_router
from backend.apis.rol_api import router as roles_router
from backend.apis.usuario_api import router as usuarios_router
from backend.errors import (
    AreaDuplicada,
    AreaNoEncontrada,
    CategoriaDuplicada,
    CategoriaInvalida,
    CategoriaNoEncontrada,
    ConflictoEstado,
    CredencialesInvalidas,
    DatosInvalidos,
    LoteNoEncontrado,
    LoteVencido,
    PermisoDenegado,
    PermisoNoEncontrado,
    ProductoDuplicado,
    ProductoNoEncontrado,
    ReferenciaInvalida,
    RolDuplicado,
    RolNoEncontrado,
    StockInsuficiente,
    TokenInvalido,
    UsuarioDuplicado,
    UsuarioNoEncontrado,
)

app = FastAPI(
    title="SIGIH API",
    version="0.2.0",
    description="Sistema de Gestión de Inventario Hospitalario",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4200"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(usuarios_router)
app.include_router(roles_router)
app.include_router(permisos_router)
app.include_router(categorias_router)
app.include_router(productos_router)
app.include_router(lotes_router)
app.include_router(movimientos_router)
app.include_router(areas_router)
app.include_router(alertas_router)
app.include_router(dashboard_router)
app.include_router(reportes_router)


@app.exception_handler(CategoriaNoEncontrada)
@app.exception_handler(ProductoNoEncontrado)
@app.exception_handler(LoteNoEncontrado)
@app.exception_handler(UsuarioNoEncontrado)
@app.exception_handler(RolNoEncontrado)
@app.exception_handler(PermisoNoEncontrado)
@app.exception_handler(AreaNoEncontrada)
async def recurso_no_encontrado(request: Request, exc: Exception) -> JSONResponse:
    """404 cuando el recurso solicitado no existe."""
    return JSONResponse(status_code=404, content={"detail": str(exc)})


@app.exception_handler(CategoriaDuplicada)
@app.exception_handler(ProductoDuplicado)
@app.exception_handler(UsuarioDuplicado)
@app.exception_handler(RolDuplicado)
@app.exception_handler(AreaDuplicada)
@app.exception_handler(StockInsuficiente)
@app.exception_handler(LoteVencido)
@app.exception_handler(ConflictoEstado)
async def conflicto_estado(request: Request, exc: Exception) -> JSONResponse:
    """409 cuando la operación choca con el estado actual de los datos."""
    return JSONResponse(status_code=409, content={"detail": str(exc)})


@app.exception_handler(CategoriaInvalida)
@app.exception_handler(ReferenciaInvalida)
async def referencia_invalida(request: Request, exc: Exception) -> JSONResponse:
    """400 cuando una referencia (categoría, producto, usuario o área) no sirve."""
    return JSONResponse(status_code=400, content={"detail": str(exc)})


@app.exception_handler(DatosInvalidos)
async def datos_invalidos(request: Request, exc: Exception) -> JSONResponse:
    """422 cuando los datos violan una restricción de la base."""
    return JSONResponse(status_code=422, content={"detail": str(exc)})


@app.exception_handler(PermisoDenegado)
async def permiso_denegado(request: Request, exc: Exception) -> JSONResponse:
    """403 cuando el usuario autenticado no tiene el permiso requerido."""
    return JSONResponse(status_code=403, content={"detail": str(exc)})


@app.exception_handler(CredencialesInvalidas)
@app.exception_handler(TokenInvalido)
async def no_autenticado(request: Request, exc: Exception) -> JSONResponse:
    """401 cuando faltan credenciales válidas o el token no sirve."""
    return JSONResponse(
        status_code=401,
        content={"detail": str(exc)},
        headers={"WWW-Authenticate": "Bearer"},
    )
