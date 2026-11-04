import { Component, HostListener, inject, ChangeDetectionStrategy } from '@angular/core';
import type { VarianteConfirmacion } from '../../../core/services/confirmacion.service';
import { ConfirmacionService } from '../../../core/services/confirmacion.service';

const CLASES: Record<VarianteConfirmacion, string> = {
  peligro: 'btn-danger',
  advertencia: 'btn-warning',
  info: 'btn-primary',
};

const ICONOS: Record<VarianteConfirmacion, string> = {
  peligro: 'bi-exclamation-octagon',
  advertencia: 'bi-exclamation-triangle',
  info: 'bi-info-circle',
};

/** Diálogo modal compartido para confirmar acciones destructivas. */
@Component({
  selector: 'app-confirm-dialog',
  templateUrl: './confirm-dialog.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './confirm-dialog.scss',
})
export class ConfirmDialog {
  protected readonly confirmacion = inject(ConfirmacionService);

  protected claseBoton(variante: VarianteConfirmacion): string {
    return CLASES[variante];
  }

  protected iconoPorDefecto(variante: VarianteConfirmacion): string {
    return ICONOS[variante];
  }

  protected aceptar(): void {
    this.confirmacion.aceptar();
  }

  protected cancelar(): void {
    this.confirmacion.cancelar();
  }

  @HostListener('document:keydown.escape')
  protected alPulsarEscape(): void {
    if (this.confirmacion.solicitud()) {
      this.cancelar();
    }
  }
}
