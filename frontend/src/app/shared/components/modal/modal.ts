import { Component, HostListener, input, output, ChangeDetectionStrategy } from '@angular/core';

export type TamanoModal = 'sm' | 'lg' | 'xl';

/**
 * Envoltorio de modal Bootstrap reutilizable.
 *
 * El componente se instancia solo cuando el modal está abierto; el contenido
 * se proyecta en el cuerpo y los botones marcados con ``modalPie`` van al pie.
 *
 * ```html
 * <app-modal titulo="Nuevo producto" (cerrar)="cerrar()">
 *   <form>...</form>
 *   <div modalPie class="d-flex gap-2">
 *     <button class="btn btn-outline-secondary">Cancelar</button>
 *     <button class="btn btn-primary">Guardar</button>
 *   </div>
 * </app-modal>
 * ```
 */
@Component({
  selector: 'app-modal',
  templateUrl: './modal.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './modal.scss',
})
export class Modal {
  readonly titulo = input.required<string>();
  readonly subtitulo = input<string>('');
  readonly tamano = input<TamanoModal>('lg');
  readonly cerrar = output<void>();

  protected alCerrar(): void {
    this.cerrar.emit();
  }

  @HostListener('document:keydown.escape')
  protected alPulsarEscape(): void {
    this.alCerrar();
  }
}
