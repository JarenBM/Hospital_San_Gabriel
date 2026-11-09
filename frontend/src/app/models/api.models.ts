/**
 * Contratos transversales de la API.
 *
 * ``DecimalString`` recuerda que Pydantic v2 serializa ``Decimal`` como
 * string (por ejemplo ``"12.50"``), no como número. El frontend debe
 * convertirlo con ``Number(...)`` antes de operar.
 */
export type DecimalString = string;

/** Fecha ISO sin hora: ``YYYY-MM-DD``. */
export type FechaISO = string;

/** Fecha y hora ISO 8601, por ejemplo ``2026-11-02T14:30:00``. */
export type FechaHoraISO = string;

/** Identificador numérico positivo. */
export type Id = number;

/** Respuesta de FastAPI cuando la validación de Pydantic falla (HTTP 422). */
export interface ApiValidationIssue {
  type: string;
  loc: Array<string | number>;
  msg: string;
  input?: unknown;
  ctx?: Record<string, unknown>;
}

/** Error normalizado que consumen los servicios y la UI. */
export interface ApiError {
  /** Código HTTP; 0 indica que no hubo conexión con el servidor. */
  status: number;
  /** Mensaje corto listo para mostrar. */
  mensaje: string;
  /** Detalle opcional del backend o de la validación. */
  detalle?: string;
  /** Errores campo a campo cuando el backend responde 422. */
  validacion?: ApiValidationIssue[];
}

/** Respuesta de los endpoints que devuelven un contador, como sincronizar permisos. */
export interface RespuestaTotal {
  total: number;
}

/** Filtros de listado comunes. */
export interface FiltrosBase {
  solo_activos?: boolean | null;
}
