import { inject } from '@angular/core';
import type { CanActivateFn } from '@angular/router';
import { Router } from '@angular/router';
import { map } from 'rxjs';
import { AuthService } from '../services/auth.service';

/**
 * Protege las rutas privadas.
 *
 * Si hay una restauración de sesión en curso (recarga del navegador) espera a
 * que termine antes de decidir. Si no hay token, redirige a ``/login``
 * conservando la URL solicitada en ``returnUrl``.
 */
export const authGuard: CanActivateFn = (_ruta, estado) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  const irALogin = () =>
    router.createUrlTree(['/login'], {
      queryParams: { returnUrl: estado.url },
    });

  if (auth.restaurando()) {
    return auth
      .esperarRestauracion()
      .pipe(map(() => (auth.isAutenticado() ? true : irALogin())));
  }

  return auth.isAutenticado() ? true : irALogin();
};
