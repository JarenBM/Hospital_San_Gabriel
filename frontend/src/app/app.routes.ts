import type { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';
import { guestGuard } from './core/guards/guest.guard';
import { roleGuard } from './core/guards/role.guard';
import { NAVEGACION } from './shared/components/layout/navegacion';

/**
 * Módulos todavía no implementados.
 *
 * Se generan a partir del catálogo de navegación para que la ruta, el título
 * del navbar y el permiso requerido no se dupliquen en dos sitios.
 */
const rutasModulos: Routes = NAVEGACION.filter(
  (opcion) => opcion.ruta !== '/dashboard',
).map((opcion) => ({
  path: opcion.ruta.replace(/^\//, ''),
  title: `${opcion.etiqueta} · SIGIH`,
  canActivate: [roleGuard],
  data: {
    permiso: opcion.permiso,
    titulo: opcion.etiqueta,
    descripcion: opcion.descripcion,
    icono: opcion.icono,
  },
  loadComponent: () =>
    import('./features/modulos/modulo-pendiente').then(
      (modulo) => modulo.ModuloPendiente,
    ),
}));

/**
 * Rutas de SIGIH.
 *
 * - ``/login`` es público (``guestGuard`` aleja a quien ya tiene sesión).
 * - El layout protegido agrupa dashboard y módulos bajo ``authGuard``.
 * - ``/403`` y ``/404`` son páginas independientes, sin layout.
 * - Cualquier URL desconocida termina en ``/404``.
 */
export const routes: Routes = [
  {
    path: 'login',
    title: 'Iniciar sesión · SIGIH',
    canActivate: [guestGuard],
    loadComponent: () =>
      import('./features/auth/login/login').then((modulo) => modulo.Login),
  },
  {
    path: '403',
    title: 'Acceso prohibido · SIGIH',
    loadComponent: () =>
      import('./features/errors/forbidden/forbidden').then(
        (modulo) => modulo.Forbidden,
      ),
  },
  {
    path: '404',
    title: 'Página no encontrada · SIGIH',
    loadComponent: () =>
      import('./features/errors/not-found/not-found').then(
        (modulo) => modulo.NotFound,
      ),
  },
  {
    path: '',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./shared/components/layout/shell').then((modulo) => modulo.Shell),
    children: [
      {
        path: '',
        pathMatch: 'full',
        title: 'SIGIH · Inicio',
        redirectTo: 'dashboard',
      },
      {
        path: 'dashboard',
        title: 'Dashboard · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'dashboard:leer' },
        loadComponent: () =>
          import('./features/dashboard/dashboard').then(
            (modulo) => modulo.Dashboard,
          ),
      },
      ...rutasModulos,
      { path: '**', redirectTo: '/404' },
    ],
  },
  { path: '**', redirectTo: '/404' },
];
