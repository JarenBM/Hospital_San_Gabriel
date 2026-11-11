"""Clasificación de errores de SQL Server, compartida por los repositories."""

import re

import pyodbc

# Códigos que lanzan los SP (THROW) y restricciones de la base.
# El orden importa: se devuelve el primer tipo que coincida.
_TIPOS: tuple[tuple[str, frozenset[str]], ...] = (
    # Duplicados: unique/PK de SQL Server y nombres repetidos.
    ("duplicado", frozenset({"2627", "2601", "51402", "51502"})),
    # Recursos inexistentes.
    ("no_encontrado", frozenset({"51007", "51008", "51403", "51503", "52003", "52101"})),
    ("permiso_no_encontrado", frozenset({"52104"})),
    # Referencias inválidas o inactivas.
    ("referencia_invalida", frozenset({"51003", "51005"})),
    ("rol_invalido", frozenset({"52002"})),
    # Conflictos de estado que el cliente debe resolver.
    ("conflicto_stock", frozenset({"51009"})),
    ("conflicto_categoria", frozenset({"51404"})),
    ("ultimo_admin", frozenset({"52004"})),
    ("rol_protegido", frozenset({"52103"})),
    # Datos inválidos de entrada.
    ("datos_invalidos",
     frozenset({"51002", "51004", "51006", "51401", "51301", "51302",
                "51501", "52001", "52102", "547"})),
    ("reporte_invalido", frozenset({"51701"})),
    # Inventario (lotes, entradas y salidas).
    ("lote_no_encontrado", frozenset({"51206"})),
    ("lote_vencido", frozenset({"51108", "51208"})),
    ("stock_insuficiente", frozenset({"51209", "51210"})),
    ("usuario_invalido", frozenset({"51103", "51204"})),
    ("producto_invalido", frozenset({"51104", "51203"})),
    ("area_invalida", frozenset({"51205"})),
    ("datos_inventario_invalidos",
     frozenset({"51101", "51102", "51105", "51106", "51107", "51109",
                "51201", "51202", "51207"})),
)

# Un error de SQL Server incluye el número entre paréntesis al final del
# mensaje: "... (547) (SQLExecDirectW)". Se exige el paréntesis para no
# confundir un 547 con parte de una fecha, una cantidad o otro número.
_PATRON_CODIGO = re.compile(r"\((\d{4,5})\)")

# Respaldo cuando el mensaje no trae el número de error. El SQLSTATE es el
# primer argumento de pyodbc.Error (23000 = violación de integridad).
_SQLSTATE_TIPOS = {"23000": "datos_invalidos"}


def _extraer_codigos(error: pyodbc.Error) -> frozenset[str]:
    """Devuelve los números de error SQL Server presentes en el mensaje."""
    return frozenset(_PATRON_CODIGO.findall(str(error)))


def _sqlstate(error: pyodbc.Error) -> str | None:
    """Devuelve el SQLSTATE del error, si pyodbc lo expone."""
    if not error.args:
        return None
    valor = error.args[0]
    return valor if isinstance(valor, str) else None


def clasificar(error: pyodbc.Error) -> str | None:
    """Devuelve el tipo de error de dominio, o None si no lo reconoce.

    Solo clasifica: cada repository decide qué excepción lanzar y con qué
    mensaje, para no acoplar los módulos entre sí.
    """
    codigos = _extraer_codigos(error)

    for tipo, esperados in _TIPOS:
        if codigos & esperados:
            return tipo

    return _SQLSTATE_TIPOS.get(_sqlstate(error) or "")
