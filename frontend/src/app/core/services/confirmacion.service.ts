import { Injectable, signal } from '@angular/core';

/** Variante visual del diálogo de confirmación. */
export type VarianteConfirmacion = 'peligro' | 'advertencia' | 'info';

export interface OpcionesConfirmacion {
  titulo: string;
  mensaje: string;
  detalle?: string;
  textoConfirmar?: string;
  textoCancelar?: string;
  variante?: VarianteConfirmacion;
  icono?: string;
}

/**
 * Confirmaciones modales dinámicas.
 *
 * ``confirmar()`` devuelve una promesa que se resuelve con la decisión del
 * usuario. Un único ``<app-confirm-dialog />`` en la raíz atiende todas las
 * peticiones, incluso si ya hay un modal de formulario abierto.
 */
@Injectable({ providedIn: 'root' })
export class ConfirmacionService {
  private readonly _solicitud = signal<OpcionesConfirmacion | null>(null);
  private resolver: ((aceptada: boolean) => void) | null = null;

  readonly solicitud = this._solicitud.asReadonly();

  confirmar(opciones: OpcionesConfirmacion): Promise<boolean> {
    // Si había otra confirmación pendiente, se descarta como cancelada.
    this.resolver?.(false);

    this._solicitud.set({
      textoConfirmar: 'Confirmar',
      textoCancelar: 'Cancelar',
      variante: 'peligro',
      icono: 'bi-exclamation-triangle',
      ...opciones,
    });

    return new Promise<boolean>((resolver) => {
      this.resolver = resolver;
    });
  }

  aceptar(): void {
    this.cerrar(true);
  }

  cancelar(): void {
    this.cerrar(false);
  }

  private cerrar(aceptada: boolean): void {
    const resolver = this.resolver;
    this.resolver = null;
    this._solicitud.set(null);
    resolver?.(aceptada);
  }
}
