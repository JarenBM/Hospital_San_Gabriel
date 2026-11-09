import type { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';
import { guestGuard } from './core/guards/guest.guard';
import { roleGuard } from './core/guards/role.guard';

/**
 * Rutas de SIGIH.
 *
 * - ``/login`` es público (``guestGuard`` aleja a quien ya tiene sesión).
 * - El layout protegido agrupa dashboard y módulos bajo ``authGuard``;
 *   cada módulo exige además el permiso declarado en ``NAVEGACION``.
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
        data: { permiso: 'dashboard:leer', titulo: 'Dashboard' },
        loadComponent: () =>
          import('./features/dashboard/dashboard').then(
            (modulo) => modulo.Dashboard,
          ),
      },
      {
        path: 'productos',
        title: 'Productos · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'productos:leer', titulo: 'Productos' },
        loadComponent: () =>
          import('./features/productos/productos').then(
            (modulo) => modulo.Productos,
          ),
      },
      {
        path: 'categorias',
        title: 'Categorías · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'categorias:leer', titulo: 'Categorías' },
        loadComponent: () =>
          import('./features/categorias/categorias').then(
            (modulo) => modulo.Categorias,
          ),
      },
      {
        path: 'lotes',
        title: 'Lotes · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'lotes:leer', titulo: 'Lotes' },
        loadComponent: () =>
          import('./features/lotes/lotes').then((modulo) => modulo.Lotes),
      },
      {
        path: 'movimientos',
        title: 'Movimientos · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'movimientos:leer', titulo: 'Movimientos' },
        loadComponent: () =>
          import('./features/movimientos/movimientos').then(
            (modulo) => modulo.Movimientos,
          ),
      },
      {
        path: 'alertas',
        title: 'Alertas · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'alertas:leer', titulo: 'Alertas' },
        loadComponent: () =>
          import('./features/alertas/alertas').then((modulo) => modulo.Alertas),
      },
      {
        path: 'reportes',
        title: 'Reportes · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'reportes:leer', titulo: 'Reportes' },
        loadComponent: () =>
          import('./features/reportes/reportes').then(
            (modulo) => modulo.Reportes,
          ),
      },
      {
        path: 'areas',
        title: 'Áreas · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'areas:leer', titulo: 'Áreas' },
        loadComponent: () =>
          import('./features/areas/areas').then((modulo) => modulo.Areas),
      },
      {
        path: 'usuarios',
        title: 'Usuarios · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'usuarios:gestionar', titulo: 'Usuarios' },
        loadComponent: () =>
          import('./features/usuarios/usuarios').then(
            (modulo) => modulo.Usuarios,
          ),
      },
      {
        path: 'roles',
        title: 'Roles · SIGIH',
        canActivate: [roleGuard],
        data: { permiso: 'roles:gestionar', titulo: 'Roles' },
        loadComponent: () =>
          import('./features/roles/roles').then((modulo) => modulo.Roles),
      },
      { path: '**', redirectTo: '/404' },
    ],
  },
  { path: '**', redirectTo: '/404' },
];
