import { Component, inject, ChangeDetectionStrategy } from '@angular/core';
import type { TipoToast } from '../../../core/services/toast.service';
import { ToastService } from '../../../core/services/toast.service';

const ICONOS: Record<TipoToast, string> = {
  exito: 'bi-check-circle-fill',
  error: 'bi-x-octagon-fill',
  advertencia: 'bi-exclamation-triangle-fill',
  info: 'bi-info-circle-fill',
};

const TITULOS: Record<TipoToast, string> = {
  exito: 'Operación exitosa',
  error: 'Error',
  advertencia: 'Atención',
  info: 'Información',
};

/** Contenedor de toasts de Bootstrap, fijo en la esquina superior derecha. */
@Component({
  selector: 'app-toasts',
  templateUrl: './toasts.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './toasts.scss',
})
export class Toasts {
  protected readonly toasts = inject(ToastService);

  protected icono(tipo: TipoToast): string {
    return ICONOS[tipo];
  }

  protected titulo(tipo: TipoToast): string {
    return TITULOS[tipo];
  }

  protected descartar(id: number): void {
    this.toasts.descartar(id);
  }
}
