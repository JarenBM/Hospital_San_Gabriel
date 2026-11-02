import type { DecimalString, FechaISO, Id } from './api.models';

/** Contratos de alertas y dashboard (solo lectura). */

/** Fila de ``sp_Alertas_StockBajo``. */
export interface ProductoStockBajo {
  id_producto: Id;
  codigo: string;
  nombre: string;
  stock_minimo: number;
  stock_disponible: number;
}

/** Estado que calcula SQL Server en ``sp_Alertas_PorVencer``. */
export type EstadoVencimiento = 'PROXIMO' | 'VENCIDO';

/** Fila de ``sp_Alertas_PorVencer``. */
export interface LoteAlerta {
  codigo: string;
  nombre: string;
  numero_lote: string | null;
  fecha_vencimiento: FechaISO;
  stock_actual: number;
  estado: EstadoVencimiento;
}

/** Fila de ``sp_Dashboard_Resumen``. */
export interface ResumenInventario {
  productos_activos: number;
  productos_stock_bajo: number;
  lotes_vencidos: number;
  lotes_proximos_vencer: number;
  /** Pydantic serializa ``Decimal`` como string. */
  valor_referencial_inventario: DecimalString;
  movimientos_periodo: number;
}
