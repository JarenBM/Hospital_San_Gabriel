import type { Id } from './api.models';

/** Contratos de categorías (``/api/categorias``). */

/** Fila de ``sp_Categorias_Listar`` / ``sp_Categorias_Obtener``. */
export interface Categoria {
  id_categoria: Id;
  nombre: string;
  descripcion: string | null;
  activo: boolean;
}

/** Cuerpo de ``POST /api/categorias``. */
export interface CategoriaCrear {
  nombre: string;
  descripcion?: string | null;
}

/**
 * Cuerpo de ``PUT /api/categorias/{id}``.
 *
 * ``activo`` nulo conserva el estado actual; ``true`` reactiva.
 */
export interface CategoriaActualizar {
  nombre: string;
  descripcion?: string | null;
  activo?: boolean | null;
}
