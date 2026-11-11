import type { DecimalString, Id, Paginacion } from './api.models';

/** Contratos de productos (``/api/productos``). */

/** Fila de ``sp_Productos_Obtener``. */
export interface Producto {
  id_producto: Id;
  id_categoria: Id;
  codigo: string;
  nombre: string;
  descripcion: string | null;
  unidad_medida: string;
  /** Pydantic serializa ``Decimal`` como string: ``"12.50"``. */
  precio_unitario: DecimalString;
  stock_minimo: number;
  maneja_lotes: boolean;
  requiere_vencimiento: boolean;
  activo: boolean;
}

/**
 * Fila de ``sp_Productos_Listar``.
 *
 * Añade el nombre de la categoría y el stock calculado desde los lotes.
 */
export interface ProductoListado extends Producto {
  categoria: string;
  stock_total: number;
  stock_disponible: number;
}

/**
 * Cuerpo de ``POST /api/productos``.
 *
 * ``maneja_lotes`` y ``requiere_vencimiento`` solo se fijan al crear.
 */
export interface ProductoCrear {
  id_categoria: Id;
  codigo: string;
  nombre: string;
  descripcion?: string | null;
  unidad_medida: string;
  precio_unitario: DecimalString | number;
  stock_minimo?: number;
  maneja_lotes?: boolean;
  requiere_vencimiento?: boolean;
}

/**
 * Cuerpo de ``PUT /api/productos/{id}``.
 *
 * No admite ``activo``, ``maneja_lotes`` ni ``requiere_vencimiento``: el
 * backend los ignora y no existe reactivación de productos.
 */
export interface ProductoActualizar {
  id_categoria: Id;
  codigo: string;
  nombre: string;
  descripcion?: string | null;
  unidad_medida: string;
  precio_unitario: DecimalString | number;
  stock_minimo?: number;
}

/** Filtros de ``GET /api/productos``. */
export interface FiltrosProducto extends Paginacion {
  busqueda?: string | null;
  id_categoria?: Id | null;
  solo_activos?: boolean | null;
}
