import { Component, computed, inject, input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';

/**
 * Marcador para los módulos que todavía no se implementan.
 *
 * Recibe ``titulo``, ``descripcion`` e ``icono`` desde ``data`` de la ruta
 * (``withComponentInputBinding``), de modo que un único componente cubre
 * productos, lotes, movimientos, reportes, usuarios, roles, etc.
 */
@Component({
  selector: 'app-modulo-pendiente',
  imports: [RouterLink],
  templateUrl: './modulo-pendiente.html',
  styleUrl: './modulo-pendiente.scss',
})
export class ModuloPendiente {
  private readonly auth = inject(AuthService);

  readonly titulo = input<string>('Módulo');
  readonly descripcion = input<string>('');
  readonly icono = input<string>('bi-tools');

  protected readonly rutaInicio = computed(() => this.auth.rutaInicio());
}
