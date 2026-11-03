import type { ApiError } from '../../models';
import { detalleValidacion, normalizarErrorHttp } from './api-error';

/** Texto listo para un toast a partir de cualquier error HTTP. */
export function describirError(error: unknown): {
  mensaje: string;
  detalle?: string;
} {
  const apiError: ApiError = normalizarErrorHttp(error);
  const validacion = detalleValidacion(apiError.validacion);
  const detalle = validacion ?? apiError.detalle;

  return {
    mensaje: apiError.mensaje,
    detalle: detalle && detalle !== apiError.mensaje ? detalle : undefined,
  };
}
