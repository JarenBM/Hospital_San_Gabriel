import { Component, computed, inject, ChangeDetectionStrategy } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

/**
 * Página de error 403.
 *
 * Se muestra cuando el ``roleGuard`` rechaza una ruta porque el usuario no
 * tiene el permiso o el rol requerido. Ofrece volver a su inicio y cerrar la
 * sesión para entrar con otra cuenta.
 */
@Component({
  selector: 'app-forbidden',
  imports: [RouterLink],
  templateUrl: './forbidden.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './forbidden.scss',
})
export class Forbidden {
  private readonly auth = inject(AuthService);

  protected readonly nombre = this.auth.nombre;
  protected readonly rolActual = this.auth.rolActual;
  protected readonly rutaInicio = computed(() => this.auth.rutaInicio());

  protected cerrarSesion(): void {
    this.auth.logout();
  }
}
