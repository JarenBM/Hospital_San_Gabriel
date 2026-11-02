import type { DecimalString, FechaISO, Id } from './api.models';

/** Contratos de reportes (``/api/reportes``, solo lectura). */

/** Fila de ``sp_Reportes_MayoresSalidas``. */
export interface MayorSalida {
  id_producto: Id;
  codigo: string;
  nombre: string;
  total_salidas: number;
}

/** Fila de ``sp_Reportes_ConsumoPorArea``. */
export interface ConsumoArea {
  id_area: Id;
  area: string;
  total_movimientos: number;
  total_unidades: number;
}

/** Fila de ``sp_Reportes_StockValorizado``. */
export interface StockValorizado {
  id_producto: Id;
  codigo: string;
  nombre: string;
  categoria: string;
  stock_total: number;
  /** Pydantic serializa ``Decimal`` como string. */
  precio_unitario: DecimalString;
  /** Pydantic serializa ``Decimal`` como string. */
  valor_total: DecimalString;
}

/** Rango de fechas obligatorio para los reportes de movimientos. */
export interface RangoReporte {
  desde: FechaISO;
  hasta: FechaISO;
}

/** Parámetros de ``GET /api/reportes/mayores-salidas``. */
export interface FiltrosMayoresSalidas extends RangoReporte {
  /** Límite 1..100; por defecto 10. */
  top?: number;
}
