"""Modelos de productos intercambiados por la API."""

from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints, model_validator

# Límites reales de las columnas de dbo.Productos.
Codigo = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=30)
]
Nombre = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=150)
]
Descripcion = Annotated[
    str, StringConstraints(strip_whitespace=True, max_length=500)
]
UnidadMedida = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=30)
]
Precio = Annotated[Decimal, Field(gt=0, max_digits=12, decimal_places=2)]
StockMinimo = Annotated[int, Field(ge=0)]
IdCategoria = Annotated[int, Field(gt=0)]


class Producto(BaseModel):
    """Fila devuelta por dbo.sp_Producto_Obtener."""

    id_producto: int
    id_categoria: int
    codigo: str
    nombre: str
    descripcion: str | None = None
    unidad_medida: str
    precio_unitario: Decimal
    stock_minimo: int
    maneja_lotes: bool
    requiere_vencimiento: bool
    activo: bool


class ProductoListado(Producto):
    """Fila devuelta por dbo.sp_Producto_Listar.

    Añade el nombre de la categoría y el stock calculado a partir de los lotes.
    """

    categoria: str
    stock_total: int
    stock_disponible: int


class ProductoCrear(BaseModel):
    """Datos para dbo.sp_Producto_Crear.

    ``maneja_lotes`` y ``requiere_vencimiento`` solo se definen al crear.
    """

    id_categoria: IdCategoria
    codigo: Codigo
    nombre: Nombre
    descripcion: Descripcion | None = None
    unidad_medida: UnidadMedida
    precio_unitario: Precio
    stock_minimo: StockMinimo = 0
    maneja_lotes: bool = False
    requiere_vencimiento: bool = False

    @model_validator(mode="after")
    def validar_vencimiento(self) -> "ProductoCrear":
        """Espeja la restricción CK_Producto_Vence de la base."""
        if self.requiere_vencimiento and not self.maneja_lotes:
            raise ValueError("Un producto con vencimiento debe manejar lotes")
        return self


class ProductoActualizar(BaseModel):
    """Datos para dbo.sp_Producto_Actualizar.

    No incluye ``maneja_lotes`` ni ``requiere_vencimiento``: el SP no los
    actualiza y aceptarlos aquí los ignoraría en silencio. Tampoco incluye
    ``activo``: no existe reactivación de productos.
    """

    id_categoria: IdCategoria
    codigo: Codigo
    nombre: Nombre
    descripcion: Descripcion | None = None
    unidad_medida: UnidadMedida
    precio_unitario: Precio
    stock_minimo: StockMinimo = 0
