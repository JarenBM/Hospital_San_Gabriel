"""Dependencias compartidas por los endpoints de FastAPI."""

from typing import Annotated

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer

from backend.schemas.auth import UsuarioAutenticado
from backend.security import decodificar_token
from backend.services.auth_service import obtener_usuario_por_email

# El tokenUrl es el que usa el botón Authorize de Swagger.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def obtener_usuario_actual(
    token: Annotated[str, Depends(oauth2_scheme)],
) -> UsuarioAutenticado:
    """Resuelve el usuario del token; sin token o token inválido responde 401."""
    return obtener_usuario_por_email(decodificar_token(token))
