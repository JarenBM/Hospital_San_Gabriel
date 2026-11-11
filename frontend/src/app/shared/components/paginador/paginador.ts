import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';

/**
 * Controles de paginación para los listados del servidor.
 *
 * ```html
 * <app-paginador
 *   [pagina]="pagina()"
 *   [totalPaginas]="totalPaginas()"
 *   [total]="recurso.total()"
 *   [desde]="desde()"
 *   [hasta]="hasta()"
 *   (cambiar)="irPagina($event)"
 * />
 * ```
 */
@Component({
  selector: 'app-paginador',
  templateUrl: './paginador.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './paginador.scss',
})
export class Paginador {
  readonly pagina = input.required<number>();
  readonly totalPaginas = input.required<number>();
  readonly total = input.required<number>();
  readonly desde = input(0);
  readonly hasta = input(0);
  readonly deshabilitado = input(false);

  readonly cambiar = output<number>();

  protected readonly anteriorDeshabilitado = computed(
    () => this.deshabilitado() || this.pagina() <= 1,
  );

  protected readonly siguienteDeshabilitado = computed(
    () => this.deshabilitado() || this.pagina() >= this.totalPaginas(),
  );

  protected ir(destino: number): void {
    if (this.deshabilitado()) {
      return;
    }
    const pagina = Math.min(Math.max(destino, 1), this.totalPaginas());
    if (pagina !== this.pagina()) {
      this.cambiar.emit(pagina);
    }
  }
}
