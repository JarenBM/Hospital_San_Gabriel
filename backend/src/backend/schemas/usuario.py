"""Modelos de gestión de usuarios."""

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

NombreUsuario = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)
]
Email = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=3,
        max_length=150,
        pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
    ),
]
Password = Annotated[str, Field(min_length=8, max_length=128)]


class Usuario(BaseModel):
    """Fila de dbo.sp_Usuarios_Obtener / dbo.sp_Usuarios_Listar."""

    id_usuario: int
    nombre: str
    email: str
    activo: bool
    fecha_creacion: datetime
    roles: str | None = None


class UsuarioCrear(BaseModel):
    """Datos para crear un usuario. La contraseña viaja en claro y se hashea."""

    nombre: NombreUsuario
    email: Email
    password: Password
    id_rol: int | None = Field(default=None, gt=0)


class UsuarioActualizar(BaseModel):
    """Datos editables de un usuario. ``activo`` None conserva el estado."""

    nombre: NombreUsuario
    email: Email
    activo: bool | None = None


class UsuarioPassword(BaseModel):
    """Nueva contraseña de un usuario (reset administrativo)."""

    password: Password


class UsuarioRol(BaseModel):
    """Asignación de un rol a un usuario."""

    id_rol: int = Field(gt=0)
