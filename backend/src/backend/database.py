"""Apertura y cierre de conexiones a SQL Server mediante pyodbc."""

from collections.abc import Iterator
from contextlib import contextmanager

import pyodbc

from backend.config import obtener_cadena_conexion

TIEMPO_ESPERA_SEGUNDOS = 5


@contextmanager
def obtener_conexion() -> Iterator[pyodbc.Connection]:
    """Abre una conexión por petición y la cierra siempre al terminar."""
    # autocommit=True: al cerrar la conexión, ODBC haría rollback de la
    # transacción pendiente y las escrituras de los SP se perderían en silencio.
    conexion = pyodbc.connect(
        obtener_cadena_conexion(),
        timeout=TIEMPO_ESPERA_SEGUNDOS,
        autocommit=True,
    )
    try:
        yield conexion
    finally:
        conexion.close()
