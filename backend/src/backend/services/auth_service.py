"""Lógica de autenticación: Argon2, estado del usuario y emisión del JWT."""

from backend.errors import CredencialesInvalidas, TokenInvalido
from backend.repositories.usuario_repository import (
    obtener_sesion as obtener_sesion_repositorio,
)
from backend.schemas.auth import TokenRespuesta, UsuarioAutenticado
from backend.security import crear_token, verificar_password

# Un solo mensaje para correo inexistente, usuario inactivo y contraseña
# incorrecta: no se revela cuál de los tres falló.
MENSAJE_CREDENCIALES = "Credenciales inválidas"


def _construir_usuario(sesion: dict) -> UsuarioAutenticado:
    """Construye el usuario de sesión sin exponer ``password_hash``."""
    fila = sesion["usuario"]
    roles = [r["nombre"] for r in sesion["roles"] if r.get("activo")]
    permisos = [p["codigo"] for p in sesion["permisos"]]
    return UsuarioAutenticado(
        id_usuario=fila["id_usuario"],
        nombre=fila["nombre"],
        email=fila["email"],
        activo=bool(fila["activo"]),
        roles=roles,
        permisos=permisos,
    )


def autenticar(email: str, password: str) -> TokenRespuesta:
    """Valida las credenciales y emite un token JWT."""
    sesion = obtener_sesion_repositorio(email.strip())
    fila = sesion["usuario"]
    if fila is None or not fila["activo"]:
        raise CredencialesInvalidas(MENSAJE_CREDENCIALES)
    if not verificar_password(fila["password_hash"], password):
        raise CredencialesInvalidas(MENSAJE_CREDENCIALES)

    token, expira_en = crear_token(fila["email"])
    return TokenRespuesta(access_token=token, expira_en=expira_en)


def obtener_usuario_por_email(email: str) -> UsuarioAutenticado:
    """Usuario dueño de un token válido; falla si ya no existe o está inactivo."""
    sesion = obtener_sesion_repositorio(email)
    fila = sesion["usuario"]
    if fila is None or not fila["activo"]:
        raise TokenInvalido("La sesión ya no es válida")

    return _construir_usuario(sesion)
