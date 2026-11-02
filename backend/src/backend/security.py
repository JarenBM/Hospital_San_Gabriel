"""Primitivas de seguridad: verificación Argon2 y tokens JWT.

Este módulo no conoce FastAPI ni la base de datos: solo transforma
contraseñas y tokens. Así lo pueden usar tanto el servicio como las
dependencias sin crear imports circulares.
"""

from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from backend.config import ALGORITMO_JWT, EXPIRACION_MINUTOS, SECRETO_JWT
from backend.errors import TokenInvalido

_VERIFICADOR = PasswordHasher()


def verificar_password(password_hash: str, password: str) -> bool:
    """Compara una contraseña en claro con el hash Argon2 almacenado.

    Un hash mal formado se trata como credencial inválida, nunca como error
    500: la base podría tener filas antiguas o de prueba.
    """
    try:
        return _VERIFICADOR.verify(password_hash, password)
    except (VerificationError, InvalidHashError):
        return False


def crear_token(email: str) -> tuple[str, int]:
    """Emite un JWT firmado con HS256 y devuelve el token y su vigencia."""
    ahora = datetime.now(timezone.utc)
    token = jwt.encode(
        {
            "sub": email,
            "iat": ahora,
            "exp": ahora + timedelta(minutes=EXPIRACION_MINUTOS),
        },
        SECRETO_JWT,
        algorithm=ALGORITMO_JWT,
    )
    return token, EXPIRACION_MINUTOS * 60


def decodificar_token(token: str) -> str:
    """Valida firma y expiración, y devuelve el correo del sujeto."""
    try:
        datos = jwt.decode(token, SECRETO_JWT, algorithms=[ALGORITMO_JWT])
    except jwt.PyJWTError as error:
        raise TokenInvalido("El token no es válido o ha expirado") from error

    email = datos.get("sub")
    if not isinstance(email, str) or not email:
        raise TokenInvalido("El token no identifica a un usuario")
    return email
