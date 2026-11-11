"""Consultas de solo lectura para alertas de inventario y dashboard."""

from datetime import date

import pyodbc

from backend.errors import DatosInvalidos
from backend.repositories.base import ejecutar_lista, ejecutar_uno
from backend.repositories.errores_sql import clasificar
from backend.repositories.procedimientos import Sp


def _traducir_error(error: pyodbc.Error) -> Exception:
    """Convierte los errores de SQL Server en excepciones de dominio."""
    if clasificar(error) == "datos_invalidos":
        return DatosInvalidos("El parámetro de la consulta no es válido")
    return error


def listar_stock_bajo() -> list[dict]:
    """Ejecuta dbo.sp_Alertas_StockBajo."""
    return ejecutar_lista(Sp.ALERTAS_STOCK_BAJO)


def listar_lotes_vencimientos(dias: int) -> list[dict]:
    """Ejecuta dbo.sp_Alertas_PorVencer y devuelve PROXIMO y VENCIDO.

    El SP no tiene cota inferior: con ``dias=0`` incluye todos los lotes
    vencidos con existencias (incluidos los que vencen hoy), sin importar
    cuán antiguos sean.
    """
    try:
        return ejecutar_lista(Sp.ALERTAS_POR_VENCER, {"dias": dias})
    except pyodbc.Error as error:
        raise _traducir_error(error) from error


def obtener_resumen(
    desde: date | None = None,
    hasta: date | None = None,
) -> dict:
    """Ejecuta dbo.sp_Dashboard_Resumen con su rango de fechas opcional."""
    return ejecutar_uno(Sp.DASHBOARD_RESUMEN, {"desde": desde, "hasta": hasta}) or {}
