import { Component, computed, inject, ChangeDetectionStrategy } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

/**
 * Página de error 404.
 *
 * El comodín de rutas redirige aquí cualquier URL desconocida. El enlace
 * apunta al inicio de la aplicación (o al login si no hay sesión).
 */
@Component({
  selector: 'app-not-found',
  imports: [RouterLink],
  templateUrl: './not-found.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './not-found.scss',
})
export class NotFound {
  private readonly auth = inject(AuthService);

  protected readonly rutaInicio = computed(() => this.auth.rutaInicio());
  protected readonly autenticado = this.auth.isAutenticado;
}
