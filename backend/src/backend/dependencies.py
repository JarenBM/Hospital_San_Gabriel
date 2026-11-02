"""Dependencias compartidas por los endpoints de FastAPI, incluido el RBAC."""

from typing import Annotated, Callable

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer

from backend.errors import PermisoDenegado
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


def requiere_permiso(codigo: str) -> Callable[..., UsuarioAutenticado]:
    """Crea una dependencia que exige un permiso ``modulo:accion``.

    El usuario se vuelve a consultar en cada petición, por lo que un cambio
    de rol o una desactivación surten efecto de inmediato.
    """

    def verificar(
        usuario: Annotated[UsuarioAutenticado, Depends(obtener_usuario_actual)],
    ) -> UsuarioAutenticado:
        if codigo not in usuario.permisos:
            raise PermisoDenegado(f"Se requiere el permiso {codigo}")
        return usuario

    return verificar
