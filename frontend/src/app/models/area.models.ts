import type { Id } from './api.models';

/** Contratos de áreas hospitalarias (``/api/areas``). */

/** Fila de ``sp_Areas_Listar`` / ``sp_Areas_Obtener``. */
export interface Area {
  id_area: Id;
  nombre: string;
  activo: boolean;
}

/** Cuerpo de ``POST /api/areas``. */
export interface AreaCrear {
  nombre: string;
}

/** Cuerpo de ``PUT /api/areas/{id}``. ``activo`` nulo conserva el estado. */
export interface AreaActualizar {
  nombre: string;
  activo?: boolean | null;
}
