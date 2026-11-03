import { computed, Injectable, signal } from '@angular/core';

/** Tipos visuales de los toasts (se mapean a Bootstrap). */
export type TipoToast = 'exito' | 'error' | 'advertencia' | 'info';

/** Toast efímero mostrado en la esquina superior derecha. */
export interface Toast {
  id: number;
  tipo: TipoToast;
  mensaje: string;
  detalle?: string;
  creadoEn: number;
}

const DURACIONES: Record<TipoToast, number> = {
  exito: 4_500,
  info: 5_000,
  advertencia: 6_500,
  error: 8_000,
};

/**
 * Servicio de toasts de Bootstrap basado en signals.
 *
 * Cada toast se elimina automáticamente al cabo de unos segundos y puede
 * cerrarse manualmente desde ``<app-toasts />``.
 */
@Injectable({ providedIn: 'root' })
export class ToastService {
  private readonly _toasts = signal<Toast[]>([]);
  private secuencia = 0;

  readonly toasts = this._toasts.asReadonly();
  readonly total = computed(() => this._toasts().length);

  mostrar(tipo: TipoToast, mensaje: string, detalle?: string): number {
    const id = ++this.secuencia;
    this._toasts.update((lista) => [
      ...lista,
      { id, tipo, mensaje, detalle, creadoEn: Date.now() },
    ]);

    setTimeout(() => this.descartar(id), DURACIONES[tipo]);
    return id;
  }

  exito(mensaje: string, detalle?: string): number {
    return this.mostrar('exito', mensaje, detalle);
  }

  error(mensaje: string, detalle?: string): number {
    return this.mostrar('error', mensaje, detalle);
  }

  advertencia(mensaje: string, detalle?: string): number {
    return this.mostrar('advertencia', mensaje, detalle);
  }

  info(mensaje: string, detalle?: string): number {
    return this.mostrar('info', mensaje, detalle);
  }

  descartar(id: number): void {
    this._toasts.update((lista) => lista.filter((toast) => toast.id !== id));
  }

  limpiar(): void {
    this._toasts.set([]);
  }
}
