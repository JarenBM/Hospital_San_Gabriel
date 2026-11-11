import type { FechaHoraISO, FechaISO, Id, Paginacion } from './api.models';

/** Contratos de entradas, salidas y movimientos (``/api/movimientos``). */

/** Motivos admitidos por el enum ``MotivoEntrada`` del backend. */
export const MOTIVOS_ENTRADA = ['Compra', 'Donación', 'Devolución'] as const;

export type MotivoEntrada = (typeof MOTIVOS_ENTRADA)[number];

export type TipoMovimiento = 'ENTRADA' | 'SALIDA';

/**
 * Cuerpo de ``POST /api/movimientos/entradas``.
 *
 * ``id_usuario`` no viaja en el cuerpo: sale del token. El backend usa
 * ``extra="forbid"``, así que enviarlo responde 422.
 */
export interface EntradaCrear {
  id_producto: Id;
  cantidad: number;
  motivo: MotivoEntrada;
  numero_lote?: string | null;
  fecha_vencimiento?: FechaISO | null;
}

/** Cuerpo de ``POST /api/movimientos/salidas``. */
export interface SalidaCrear {
  id_producto: Id;
  id_lote: Id;
  id_area: Id;
  cantidad: number;
  motivo: string;
}

/** Resultado de ``POST /api/movimientos/entradas``. */
export interface EntradaRegistrada {
  id_movimiento: Id;
  id_lote: Id;
  stock_anterior: number;
  stock_posterior: number;
}

/** Resultado de ``POST /api/movimientos/salidas``. */
export interface SalidaRegistrada {
  id_movimiento: Id;
  stock_anterior: number;
  stock_posterior: number;
}

/** Fila de ``sp_Movimientos_Listar``. */
export interface MovimientoListado {
  id_movimiento: Id;
  fecha_movimiento: FechaHoraISO;
  tipo_movimiento: TipoMovimiento;
  codigo: string;
  producto: string;
  numero_lote: string | null;
  fecha_vencimiento: FechaISO | null;
  area: string | null;
  usuario: string;
  cantidad: number;
  motivo: string;
  stock_anterior: number;
  stock_posterior: number;
}

/** Filtros de ``GET /api/movimientos``. */
export interface FiltrosMovimiento extends Paginacion {
  id_producto?: Id | null;
  tipo_movimiento?: TipoMovimiento | null;
  id_area?: Id | null;
  desde?: FechaISO | null;
  hasta?: FechaISO | null;
  busqueda?: string | null;
}
