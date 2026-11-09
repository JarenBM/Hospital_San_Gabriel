"""Lógica de negocio de áreas hospitalarias."""

from backend.errors import AreaNoEncontrada
from backend.repositories import auditoria_repository
from backend.repositories.area_repository import (
    actualizar_area as actualizar_area_repositorio,
    crear_area as crear_area_repositorio,
    desactivar_area as desactivar_area_repositorio,
    listar_areas as listar_areas_repositorio,
    obtener_area as obtener_area_repositorio,
)
from backend.schemas.area import Area, AreaActualizar, AreaCrear


def listar_areas(solo_activos: bool | None = None) -> list[Area]:
    """Devuelve todas las áreas hospitalarias."""
    filas = listar_areas_repositorio(solo_activos)
    return [Area(**fila) for fila in filas]


def obtener_area(id_area: int) -> Area:
    """Devuelve un área o lanza AreaNoEncontrada."""
    fila = obtener_area_repositorio(id_area)
    if fila is None:
        raise AreaNoEncontrada(f"El área {id_area} no existe")
    return Area(**fila)


def crear_area(datos: AreaCrear, id_actor: int | None = None) -> Area:
    """Crea un área."""
    id_area = crear_area_repositorio(datos.nombre)
    auditoria_repository.registrar(
        id_actor, "CREAR", "areas", id_area, f"Área: {datos.nombre}"
    )
    return obtener_area(id_area)


def actualizar_area(
    id_area: int, datos: AreaActualizar, id_actor: int | None = None
) -> Area:
    """Actualiza un área y devuelve su estado final."""
    actualizar_area_repositorio(id_area, datos.nombre, datos.activo)
    auditoria_repository.registrar(
        id_actor, "ACTUALIZAR", "areas", id_area, f"Área: {datos.nombre}"
    )
    return obtener_area(id_area)


def desactivar_area(id_area: int, id_actor: int | None = None) -> None:
    """Desactiva un área (eliminación lógica)."""
    desactivar_area_repositorio(id_area)
    auditoria_repository.registrar(id_actor, "DESACTIVAR", "areas", id_area)
