"""Acceso a datos de reportes mediante procedimientos almacenados."""

from datetime import date

import pyodbc

from backend.errors import DatosInvalidos
from backend.repositories.base import ejecutar_lista
from backend.repositories.errores_sql import clasificar
from backend.repositories.procedimientos import Sp


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    if clasificar(error) == "datos_invalidos":
        return DatosInvalidos("El rango del reporte no es válido")
    return error


def mayores_salidas(desde: date, hasta: date, top: int = 10) -> list[dict]:
    """Ejecuta dbo.sp_Reportes_MayoresSalidas."""
    try:
        return ejecutar_lista(
            Sp.REPORTES_MAYORES_SALIDAS,
            {"desde": desde, "hasta": hasta, "top": top},
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def consumo_por_area(desde: date, hasta: date) -> list[dict]:
    """Ejecuta dbo.sp_Reportes_ConsumoPorArea."""
    try:
        return ejecutar_lista(
            Sp.REPORTES_CONSUMO_POR_AREA, {"desde": desde, "hasta": hasta}
        )
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def stock_valorizado() -> list[dict]:
    """Ejecuta dbo.sp_Reportes_StockValorizado."""
    return ejecutar_lista(Sp.REPORTES_STOCK_VALORIZADO)
