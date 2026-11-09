"""Configuración de la aplicación leída desde el archivo .env."""

import os

from dotenv import load_dotenv

load_dotenv()

_SERVIDOR = os.getenv("DB_SERVER", r".\SQLEXPRESS")
_BASE_DATOS = os.getenv("DB_NAME", "SIGIH")
_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
_USUARIO = os.getenv("DB_USER", "")
_CONTRASENA = os.getenv("DB_PASSWORD", "")

_SECRETO_JWT = os.getenv("JWT_SECRET", "")
_EXPIRACION_MINUTOS = os.getenv("JWT_EXPIRACION_MINUTOS", "60")

ALGORITMO_JWT = "HS256"
_LARGO_MINIMO_SECRETO = 32


def obtener_cadena_conexion() -> str:
    """Construye la cadena de conexión de pyodbc (sin puerto explícito)."""
    if not _USUARIO or not _CONTRASENA:
        raise RuntimeError(
            "Faltan DB_USER y DB_PASSWORD en el archivo .env (ver .env.example)."
        )

    return (
        f"DRIVER={{{_DRIVER}}};"
        f"SERVER={_SERVIDOR};"
        f"DATABASE={_BASE_DATOS};"
        f"UID={_USUARIO};"
        f"PWD={_CONTRASENA};"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )


def obtener_config_jwt() -> tuple[str, int]:
    """Devuelve el secreto JWT y la expiración en minutos.

    El secreto nunca vive en el código: solo en .env. Se exige un largo mínimo
    para que nadie arranque la API con una clave débil.
    """
    if len(_SECRETO_JWT) < _LARGO_MINIMO_SECRETO:
        raise RuntimeError(
            "JWT_SECRET falta en .env o tiene menos de "
            f"{_LARGO_MINIMO_SECRETO} caracteres. Genera uno con: "
            'uv run python -c "import secrets; print(secrets.token_urlsafe(48))"'
        )

    try:
        expiracion = int(_EXPIRACION_MINUTOS)
    except ValueError:
        raise RuntimeError("JWT_EXPIRACION_MINUTOS debe ser un número entero") from None

    if expiracion <= 0:
        raise RuntimeError("JWT_EXPIRACION_MINUTOS debe ser mayor que cero")

    return _SECRETO_JWT, expiracion


# Se valida al importar: la API no arranca sin una configuración JWT válida.
SECRETO_JWT, EXPIRACION_MINUTOS = obtener_config_jwt()
