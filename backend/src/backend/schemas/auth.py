"""Modelos de autenticación."""

from typing import Literal

from pydantic import BaseModel


class TokenRespuesta(BaseModel):
    """Token emitido tras validar el correo y la contraseña.

    ``access_token`` y ``token_type`` son los campos que espera Swagger para
    el flujo OAuth2 password.
    """

    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expira_en: int


class UsuarioAutenticado(BaseModel):
    """Usuario de la sesión actual. Nunca incluye ``password_hash``."""

    id_usuario: int
    nombre: str
    email: str
    activo: bool
