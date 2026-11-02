"""Excepciones de dominio del backend SIGIH (sin dependencias de FastAPI)."""


class CategoriaNoEncontrada(Exception):
    """La categoría solicitada no existe."""


class CategoriaDuplicada(Exception):
    """Ya existe una categoría con ese nombre."""


class CategoriaInvalida(Exception):
    """La categoría indicada no existe o está inactiva."""


class ProductoNoEncontrado(Exception):
    """El producto solicitado no existe."""


class ProductoDuplicado(Exception):
    """Ya existe un producto con ese código."""


class DatosInvalidos(Exception):
    """Los datos no cumplen una restricción de la base de datos."""


class LoteNoEncontrado(Exception):
    """El lote solicitado no existe."""


class LoteVencido(Exception):
    """El lote está vencido y no admite la operación."""


class StockInsuficiente(Exception):
    """No hay existencias suficientes en el lote."""


class ReferenciaInvalida(Exception):
    """Un producto, usuario o área indicados no son válidos o están inactivos."""


class CredencialesInvalidas(Exception):
    """El correo o la contraseña no son correctos, o el usuario está inactivo."""


class TokenInvalido(Exception):
    """El token de acceso falta, es inválido, expiró o su usuario ya no sirve."""
