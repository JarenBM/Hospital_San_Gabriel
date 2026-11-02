"""Ejecución centralizada de procedimientos almacenados vía pyodbc.

Reglas:
- Solo se ejecutan nombres del catálogo ``procedimientos.Sp``.
- Los valores siempre viajan como parámetros ``?`` (nunca interpolados).
- No se abre ni se confirma ninguna transacción: los SP que mueven stock ya
  gestionan su propia transacción.
"""

import re
from collections.abc import Mapping
from typing import Any

import pyodbc

from backend.database import obtener_conexion
from backend.repositories.procedimientos import PERMITIDOS

_PATRON_PARAMETRO = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _construir(nombre: str, parametros: Mapping[str, Any] | None) -> tuple[str, tuple]:
    """Devuelve el EXEC parametrizado y sus valores en orden."""
    if nombre not in PERMITIDOS:
        raise ValueError(f"Procedimiento no permitido: {nombre}")

    if not parametros:
        return f"EXEC {nombre}", ()

    for clave in parametros:
        if not _PATRON_PARAMETRO.match(clave):
            raise ValueError(f"Nombre de parámetro inválido: {clave}")

    lista = ", ".join(f"@{clave} = ?" for clave in parametros)
    return f"EXEC {nombre} {lista}", tuple(parametros.values())


def _filas(cursor: pyodbc.Cursor) -> list[dict]:
    """Convierte el result set actual en diccionarios."""
    if cursor.description is None:
        return []
    columnas = [columna[0] for columna in cursor.description]
    return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]


def ejecutar_lista(
    nombre: str, parametros: Mapping[str, Any] | None = None
) -> list[dict]:
    """Ejecuta un SP que devuelve una lista de filas."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        sql, valores = _construir(nombre, parametros)
        cursor.execute(sql, *valores)
        return _filas(cursor)


def ejecutar_uno(
    nombre: str, parametros: Mapping[str, Any] | None = None
) -> dict | None:
    """Ejecuta un SP que devuelve cero o una fila."""
    filas = ejecutar_lista(nombre, parametros)
    return filas[0] if filas else None


def ejecutar_escalar(
    nombre: str, parametros: Mapping[str, Any] | None = None
) -> Any:
    """Ejecuta un SP y devuelve la primera columna de la primera fila."""
    fila = ejecutar_uno(nombre, parametros)
    if not fila:
        return None
    return next(iter(fila.values()))


def ejecutar_multiples(
    nombre: str, parametros: Mapping[str, Any] | None = None
) -> list[list[dict]]:
    """Ejecuta un SP que devuelve varios result sets."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        sql, valores = _construir(nombre, parametros)
        cursor.execute(sql, *valores)

        resultados: list[list[dict]] = []
        while True:
            resultados.append(_filas(cursor))
            if not cursor.nextset():
                break
        return resultados


def ejecutar_accion(
    nombre: str, parametros: Mapping[str, Any] | None = None
) -> None:
    """Ejecuta un SP de escritura y consume todos sus result sets."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        sql, valores = _construir(nombre, parametros)
        cursor.execute(sql, *valores)
        while cursor.nextset():
            pass
