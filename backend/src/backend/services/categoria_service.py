"""Lógica de negocio de categorías."""

from backend.errors import CategoriaNoEncontrada
from backend.repositories.categoria_repository import (
    actualizar_categoria as actualizar_categoria_repositorio,
    crear_categoria as crear_categoria_repositorio,
    desactivar_categoria as desactivar_categoria_repositorio,
    listar_categorias as listar_categorias_repositorio,
    obtener_categoria as obtener_categoria_repositorio,
)
from backend.schemas.categoria import Categoria


def listar_categorias() -> list[Categoria]:
    """Devuelve todas las categorías, activas e inactivas."""
    filas = listar_categorias_repositorio()
    return [Categoria(**fila) for fila in filas]


def obtener_categoria(id_categoria: int) -> Categoria:
    """Devuelve una categoría o lanza CategoriaNoEncontrada."""
    fila = obtener_categoria_repositorio(id_categoria)
    if fila is None:
        raise CategoriaNoEncontrada(f"La categoría {id_categoria} no existe")
    return Categoria(**fila)


def crear_categoria(nombre: str, descripcion: str | None) -> Categoria:
    """Registra una categoría y devuelve el objeto creado."""
    id_categoria = crear_categoria_repositorio(nombre, descripcion)
    return Categoria(
        id_categoria=id_categoria,
        nombre=nombre,
        descripcion=descripcion,
        activo=True,
    )


def actualizar_categoria(
    id_categoria: int,
    nombre: str,
    descripcion: str | None,
    activo: bool | None,
) -> Categoria:
    """Actualiza una categoría y devuelve su estado final.

    Si ``activo`` es None, el estado no cambia (no se reactiva sola).
    """
    actualizar_categoria_repositorio(id_categoria, nombre, descripcion, activo)
    return obtener_categoria(id_categoria)


def desactivar_categoria(id_categoria: int) -> None:
    """Desactiva una categoría (eliminación lógica, idempotente)."""
    desactivar_categoria_repositorio(id_categoria)
