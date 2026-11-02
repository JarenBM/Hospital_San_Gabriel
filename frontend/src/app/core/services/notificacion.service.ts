import { computed, Injectable, signal } from '@angular/core';

/** Tipos visuales de notificación (se mapean a clases de Bootstrap). */
export type TipoNotificacion = 'exito' | 'error' | 'advertencia' | 'info';

/** Notificación efímera mostrada por la UI. */
export interface Notificacion {
  id: number;
  tipo: TipoNotificacion;
  titulo: string;
  mensaje?: string;
  detalle?: string;
  creadaEn: number;
}

export interface OpcionesNotificacion {
  titulo?: string;
  detalle?: string;
  /** ``0`` desactiva el cierre automático. */
  duracionMs?: number;
}

const TITULOS: Record<TipoNotificacion, string> = {
  exito: 'Operación exitosa',
  error: 'Error',
  advertencia: 'Advertencia',
  info: 'Información',
};

const DURACIONES: Record<TipoNotificacion, number> = {
  exito: 4_000,
  info: 4_500,
  advertencia: 6_000,
  error: 8_000,
};

/**
 * Cola reactiva de notificaciones basada en signals.
 *
 * Los interceptores la usan para informar 401/403/409/500 y las páginas
 * pueden usarla para confirmar escrituras. No inyecta nada, así que se puede
 * consumir desde cualquier capa.
 */
@Injectable({ providedIn: 'root' })
export class NotificacionService {
  private readonly _notificaciones = signal<Notificacion[]>([]);
  private readonly _ultimaFirma = signal<{ firma: string; momento: number } | null>(null);
  private secuencia = 0;

  readonly notificaciones = this._notificaciones.asReadonly();
  readonly total = computed(() => this._notificaciones().length);
  readonly hayNotificaciones = computed(() => this.total() > 0);
  readonly ultima = computed(() => this._notificaciones().at(-1) ?? null);

  /** Agrega una notificación y programa su cierre automático. */
  mostrar(tipo: TipoNotificacion, mensaje: string, opciones: OpcionesNotificacion = {}): number {
    const firma = `${tipo}|${mensaje}|${opciones.detalle ?? ''}`;
    const anterior = this._ultimaFirma();
    const ahora = Date.now();

    // Evita ráfagas idénticas cuando varias peticiones fallan a la vez.
    if (anterior && anterior.firma === firma && ahora - anterior.momento < 1_500) {
      return this._notificaciones().at(-1)?.id ?? 0;
    }

    const id = ++this.secuencia;
    const notificacion: Notificacion = {
      id,
      tipo,
      titulo: opciones.titulo ?? TITULOS[tipo],
      mensaje,
      detalle: opciones.detalle,
      creadaEn: ahora,
    };

    this._ultimaFirma.set({ firma, momento: ahora });
    this._notificaciones.update((lista) => [...lista, notificacion]);

    const duracion = opciones.duracionMs ?? DURACIONES[tipo];
    if (duracion > 0) {
      setTimeout(() => this.descartar(id), duracion);
    }
    return id;
  }

  exito(mensaje: string, detalle?: string): number {
    return this.mostrar('exito', mensaje, { detalle });
  }

  error(mensaje: string, detalle?: string): number {
    return this.mostrar('error', mensaje, { detalle });
  }

  advertencia(mensaje: string, detalle?: string): number {
    return this.mostrar('advertencia', mensaje, { detalle });
  }

  info(mensaje: string, detalle?: string): number {
    return this.mostrar('info', mensaje, { detalle });
  }

  /** Quita una notificación por id. */
  descartar(id: number): void {
    this._notificaciones.update((lista) =>
      lista.filter((notificacion) => notificacion.id !== id),
    );
  }

  /** Vacía la cola. */
  limpiar(): void {
    this._notificaciones.set([]);
  }
}
