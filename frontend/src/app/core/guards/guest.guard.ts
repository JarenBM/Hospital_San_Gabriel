import { inject } from '@angular/core';
import type { CanActivateFn } from '@angular/router';
import { Router } from '@angular/router';
import { map } from 'rxjs';
import { AuthService } from '../services/auth.service';

/**
 * Mantiene al usuario autenticado fuera de ``/login``.
 *
 * Si ya hay sesión, lo redirige a la ruta de inicio de su rol: el dashboard
 * para ADMINISTRADOR, movimientos para ALMACEN y productos para CONSULTA.
 */
export const guestGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  const redirigir = () => router.createUrlTree([auth.rutaInicio()]);

  if (auth.restaurando()) {
    return auth
      .esperarRestauracion()
      .pipe(map(() => (auth.isAutenticado() ? redirigir() : true)));
  }

  return auth.isAutenticado() ? redirigir() : true;
};
