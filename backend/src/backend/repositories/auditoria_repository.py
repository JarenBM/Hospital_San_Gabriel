"""Registro de auditoría best-effort.

Un fallo de auditoría nunca debe tumbar ni revertir la operación principal:
por eso este repositorio no propaga las excepciones.
"""

import logging

from backend.repositories.base import ejecutar_accion
from backend.repositories.procedimientos import Sp

_registro = logging.getLogger(__name__)


def registrar(
    id_usuario: int | None,
    accion: str,
    modulo: str,
    id_registro: str | int | None = None,
    detalle: str | None = None,
    ip: str | None = None,
) -> None:
    """Ejecuta dbo.sp_Auditoria_Registrar ignorando cualquier fallo."""
    try:
        ejecutar_accion(
            Sp.AUDITORIA_REGISTRAR,
            {
                "id_usuario": id_usuario,
                "accion": accion,
                "modulo": modulo,
                "id_registro": None if id_registro is None else str(id_registro),
                "detalle": detalle,
                "ip": ip,
            },
        )
    except Exception:  # noqa: BLE001 - la auditoría es best-effort
        _registro.warning("No se pudo registrar la auditoría", exc_info=True)
