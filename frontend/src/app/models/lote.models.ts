import type { FechaHoraISO, FechaISO, Id } from './api.models';

/**
 * Contratos de lotes (``GET /api/productos/{id}/lotes``).
 *
 * El stock solo cambia mediante entradas y salidas; no existe CRUD de lotes.
 */
export interface Lote {
  id_lote: Id;
  id_producto: Id;
  numero_lote: string | null;
  fecha_vencimiento: FechaISO | null;
  stock_actual: number;
  fecha_registro: FechaHoraISO;
  vencido: boolean;
}
