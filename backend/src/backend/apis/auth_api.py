"""Endpoints HTTP de autenticación."""

from typing import Annotated

from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm

from backend.dependencies import obtener_usuario_actual
from backend.schemas.auth import TokenRespuesta, UsuarioAutenticado
from backend.services.auth_service import autenticar

router = APIRouter(prefix="/api/auth", tags=["Autenticación"])


@router.post("/login", response_model=TokenRespuesta)
def login(datos: Annotated[OAuth2PasswordRequestForm, Depends()]) -> TokenRespuesta:
    """Valida correo y contraseña y emite un JWT (OAuth2 password flow).

    Swagger envía el formulario con ``username`` (el correo) y ``password``.
    """
    return autenticar(datos.username, datos.password)


@router.get("/me", response_model=UsuarioAutenticado)
def me(
    usuario: Annotated[UsuarioAutenticado, Depends(obtener_usuario_actual)],
) -> UsuarioAutenticado:
    """Devuelve el usuario autenticado por el token, sin datos sensibles."""
    return usuario
