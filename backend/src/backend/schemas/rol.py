"""Modelos de roles y permisos."""

from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

NombreRol = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)
]
DescripcionRol = Annotated[
    str, StringConstraints(strip_whitespace=True, max_length=255)
]
CodigoPermiso = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)
]


class Rol(BaseModel):
    """Fila de dbo.sp_Roles_Listar / dbo.sp_Roles_Obtener."""

    id_rol: int
    nombre: str
    descripcion: str | None = None
    activo: bool
    total_permisos: int = 0


class RolCrear(BaseModel):
    """Datos para dbo.sp_Roles_Crear."""

    nombre: NombreRol
    descripcion: DescripcionRol | None = None


class RolActualizar(BaseModel):
    """Datos para dbo.sp_Roles_Actualizar."""

    nombre: NombreRol
    descripcion: DescripcionRol | None = None
    activo: bool | None = None


class Permiso(BaseModel):
    """Fila de dbo.sp_Permisos_Listar / dbo.sp_Permisos_Obtener."""

    id_permiso: int
    codigo: str
    modulo: str
    descripcion: str | None = None


class PermisoAsignado(BaseModel):
    """Permiso efectivo devuelto por dbo.sp_Usuarios_ListarPermisos."""

    codigo: str
    modulo: str


class RolPermisos(BaseModel):
    """Sincronización completa de los permisos de un rol."""

    permisos: list[CodigoPermiso] = Field(default_factory=list)
