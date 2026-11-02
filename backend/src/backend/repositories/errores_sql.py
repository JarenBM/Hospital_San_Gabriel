"""Clasificación de errores de SQL Server, compartida por los repositories."""

import pyodbc

# Códigos que lanzan los SP (THROW) y restricciones de la base.
# El orden importa: se devuelve el primer tipo que coincida.
_TIPOS = (
    # Duplicados: unique/PK de SQL Server y nombres repetidos.
    ("duplicado", ("2627", "2601", "51402", "51502")),
    # Recursos inexistentes.
    ("no_encontrado", ("51007", "51008", "51403", "51503", "52003", "52101")),
    ("permiso_no_encontrado", ("52104",)),
    # Referencias inválidas o inactivas.
    ("referencia_invalida", ("51003", "51005")),
    ("rol_invalido", ("52002",)),
    # Conflictos de estado que el cliente debe resolver.
    ("conflicto_stock", ("51009",)),
    ("conflicto_categoria", ("51404",)),
    ("ultimo_admin", ("52004",)),
    ("rol_protegido", ("52103",)),
    # Datos inválidos de entrada.
    ("datos_invalidos",
     ("51002", "51004", "51006", "51401", "51301", "51302",
      "51501", "52001", "52102", "547")),
    ("reporte_invalido", ("51701",)),
    # Inventario (lotes, entradas y salidas).
    ("lote_no_encontrado", ("51206",)),
    ("lote_vencido", ("51108", "51208")),
    ("stock_insuficiente", ("51209", "51210")),
    ("usuario_invalido", ("51103", "51204")),
    ("producto_invalido", ("51104", "51203")),
    ("area_invalida", ("51205",)),
    ("datos_inventario_invalidos",
     ("51101", "51102", "51105", "51106", "51107", "51109",
      "51201", "51202", "51207")),
)


def clasificar(error: pyodbc.Error) -> str | None:
    """Devuelve el tipo de error de dominio, o None si no lo reconoce.

    Solo clasifica: cada repository decide qué excepción lanzar y con qué
    mensaje, para no acoplar los módulos entre sí.
    """
    texto = str(error)
    for tipo, codigos in _TIPOS:
        if any(codigo in texto for codigo in codigos):
            return tipo
    return None
