/** Utilidades de formato compartidas por las vistas. */

const MONEDA_PEN = new Intl.NumberFormat('es-PE', {
  style: 'currency',
  currency: 'PEN',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const NUMERO = new Intl.NumberFormat('es-PE');

const FECHA_LARGA = new Intl.DateTimeFormat('es-PE', {
  dateStyle: 'long',
});

const FECHA_HORA = new Intl.DateTimeFormat('es-PE', {
  dateStyle: 'medium',
  timeStyle: 'short',
});


/**
 * Formatea un monto recibido como ``DecimalString`` (``"12.50"``) o número.
 */
export function formatearMoneda(valor: string | number | null | undefined): string {
  const numero = Number(valor ?? 0);
  return Number.isFinite(numero) ? MONEDA_PEN.format(numero) : MONEDA_PEN.format(0);
}

/** Formatea un entero con separador de miles. */
export function formatearNumero(valor: number | null | undefined): string {
  return NUMERO.format(valor ?? 0);
}

/** Formatea una fecha ISO (``YYYY-MM-DD``) en texto largo peruano. */
export function formatearFecha(valor: string | null | undefined): string {
  if (!valor) {
    return '—';
  }
  const fecha = new Date(`${valor}`.length === 10 ? `${valor}T00:00:00` : valor);
  return Number.isNaN(fecha.getTime()) ? '—' : FECHA_LARGA.format(fecha);
}

/** Formatea una fecha y hora ISO en texto corto peruano. */
export function formatearFechaHora(valor: string | null | undefined): string {
  if (!valor) {
    return '—';
  }
  const fecha = new Date(valor);
  return Number.isNaN(fecha.getTime()) ? '—' : FECHA_HORA.format(fecha);
}

/** Fecha local en formato ``YYYY-MM-DD`` para ``<input type="date">``. */
export function fechaISO(fecha: Date = new Date()): string {
  const anio = fecha.getFullYear();
  const mes = `${fecha.getMonth() + 1}`.padStart(2, '0');
  const dia = `${fecha.getDate()}`.padStart(2, '0');
  return `${anio}-${mes}-${dia}`;
}

/** Fecha local de hoy en formato ``YYYY-MM-DD``. */
export function fechaHoyISO(): string {
  return fechaISO();
}

/** Fecha local de hace ``dias`` días en formato ``YYYY-MM-DD``. */
export function fechaHaceDiasISO(dias: number): string {
  const fecha = new Date();
  fecha.setDate(fecha.getDate() - Math.max(0, dias));
  return fechaISO(fecha);
}

/** Saludo según la hora local. */
export function saludoSegunHora(fecha: Date = new Date()): string {
  const hora = fecha.getHours();
  if (hora < 12) {
    return 'Buenos días';
  }
  if (hora < 19) {
    return 'Buenas tardes';
  }
  return 'Buenas noches';
}
