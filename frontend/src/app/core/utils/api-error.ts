import { HttpErrorResponse } from '@angular/common/http';
import type { ApiError, ApiValidationIssue } from '../../models';

function esObjeto(valor: unknown): valor is Record<string, unknown> {
  return typeof valor === 'object' && valor !== null;
}

/** ``true`` si el valor ya es un ``ApiError`` normalizado. */
export function esApiError(valor: unknown): valor is ApiError {
  return (
    esObjeto(valor) &&
    typeof valor['status'] === 'number' &&
    typeof valor['mensaje'] === 'string'
  );
}

function esValidationIssue(valor: unknown): valor is ApiValidationIssue {
  return (
    esObjeto(valor) &&
    typeof valor['msg'] === 'string' &&
    Array.isArray(valor['loc'])
  );
}

function mensajePorEstado(status: number): string {
  switch (status) {
    case 400:
      return 'La solicitud no es válida';
    case 401:
      return 'Sesión expirada o credenciales inválidas';
    case 403:
      return 'No tiene permisos para realizar esta acción';
    case 404:
      return 'El recurso solicitado no existe';
    case 409:
      return 'La operación entra en conflicto con el estado actual';
    case 422:
      return 'Los datos enviados no son válidos';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'El servidor no pudo procesar la solicitud';
    default:
      return `Error HTTP ${status}`;
  }
}

interface DetalleBackend {
  mensaje?: string;
  detalle?: string;
  validacion?: ApiValidationIssue[];
}

function extraerDetalle(cuerpo: unknown): DetalleBackend {
  if (typeof cuerpo === 'string') {
    return { mensaje: cuerpo.trim() || undefined };
  }

  if (!esObjeto(cuerpo)) {
    return {};
  }

  const detalle = cuerpo['detail'];

  if (typeof detalle === 'string') {
    return { mensaje: detalle };
  }

  if (Array.isArray(detalle)) {
    const validacion = detalle.filter(esValidationIssue);
    const texto = validacion
      .map((issue) => {
        const campo = issue.loc.filter((parte) => parte !== 'body').join('.');
        return campo ? `${campo}: ${issue.msg}` : issue.msg;
      })
      .join('; ');

    return {
      mensaje: 'Los datos enviados no son válidos',
      detalle: texto || undefined,
      validacion,
    };
  }

  const message = cuerpo['message'];
  if (typeof message === 'string') {
    return { mensaje: message };
  }

  return {};
}

/**
 * Convierte cualquier error HTTP (o ya normalizado) en ``ApiError``.
 *
 * Es idempotente: si el ``ErrorInterceptor`` ya normalizó el error, se
 * devuelve tal cual para no perder el detalle.
 */
export function normalizarErrorHttp(error: unknown): ApiError {
  if (esApiError(error)) {
    return error;
  }

  if (!(error instanceof HttpErrorResponse)) {
    return {
      status: 0,
      mensaje: 'Ocurrió un error inesperado',
      detalle: error instanceof Error ? error.message : String(error),
    };
  }

  if (error.status === 0) {
    return {
      status: 0,
      mensaje: 'No se pudo conectar con el servidor',
      detalle: 'Verifique que la API esté en ejecución.',
    };
  }

  const { mensaje, detalle, validacion } = extraerDetalle(error.error);

  return {
    status: error.status,
    mensaje: mensaje ?? mensajePorEstado(error.status),
    detalle,
    validacion,
  };
}

/** Resume los errores 422 en una sola línea legible. */
export function detalleValidacion(validacion?: readonly ApiValidationIssue[]): string | undefined {
  if (!validacion?.length) {
    return undefined;
  }
  return validacion
    .map((issue) => {
      const campo = issue.loc.filter((parte) => parte !== 'body').join('.');
      return campo ? `${campo}: ${issue.msg}` : issue.msg;
    })
    .join('; ');
}
