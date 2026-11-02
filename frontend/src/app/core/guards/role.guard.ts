import { inject } from '@angular/core';
import type { CanActivateFn, UrlTree } from '@angular/router';
import { Router } from '@angular/router';
import { map } from 'rxjs';
import { AuthService } from '../services/auth.service';

/**
 * Restringe el acceso según los permisos o roles del usuario.
 *
 * Se configura con ``data`` en la ruta:
 *
 * ```ts
 * {
 *   path: 'usuarios',
 *   canActivate: [roleGuard],
 *   data: { permiso: 'usuarios:gestionar' },
 * }
 * ```
 *
 * Claves admitidas:
 * - ``permiso``: un único código ``modulo:accion``.
 * - ``permisos``: lista de códigos.
 * - ``roles``: lista de nombres de rol.
 * - ``modo``: ``'alguno'`` (por defecto) o ``'todos'`` para los permisos.
 *
 * Todas las restricciones declaradas deben cumplirse. Si fallan, redirige a
 * ``/403``.
 */
export const roleGuard: CanActivateFn = (ruta, estado) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  const evaluar = (): boolean | UrlTree => {
    if (!auth.isAutenticado()) {
      return router.createUrlTree(['/login'], {
        queryParams: { returnUrl: estado.url },
      });
    }

    const datos = ruta.data as {
      permiso?: string;
      permisos?: readonly string[];
      roles?: readonly string[];
      modo?: 'alguno' | 'todos';
    };

    if (datos.roles?.length && !datos.roles.some((rol) => auth.tieneRol(rol))) {
      return router.createUrlTree(['/403']);
    }

    const permisos = datos.permiso ? [datos.permiso] : (datos.permisos ?? []);
    if (permisos.length > 0) {
      const autorizado =
        datos.modo === 'todos'
          ? auth.tieneTodos(permisos)
          : auth.tieneAlguno(permisos);
      if (!autorizado) {
        return router.createUrlTree(['/403']);
      }
    }

    return true;
  };

  if (auth.restaurando()) {
    return auth.esperarRestauracion().pipe(map(evaluar));
  }

  return evaluar();
};
