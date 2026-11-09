import type { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { detalleValidacion, normalizarErrorHttp } from '../utils/api-error';
import { NotificacionService } from '../services/notificacion.service';
import { SessionStore } from '../services/session-store';

const RUTA_LOGIN = '/api/auth/login';

/**
 * Normaliza los errores HTTP y los notifica.
 *
 * - 401: cierra la sesión (salvo en el login) y pide volver a autenticarse.
 * - 403: el usuario no tiene el permiso ``modulo:accion`` requerido.
 * - 409: conflicto de estado (stock existente, categoría con productos...).
 * - 422: errores de validación de Pydantic, resumidos campo a campo.
 * - 5xx: fallo interno del servidor.
 * - 0: no hay conexión con la API.
 *
 * El error se reemite como ``ApiError`` para que la capa que llamó pueda
 * reaccionar (por ejemplo, marcar un formulario o detener un spinner).
 */
export const errorInterceptor: HttpInterceptorFn = (peticion, siguiente) => {
  const notificaciones = inject(NotificacionService);
  const sesion = inject(SessionStore);
  const router = inject(Router);

  return siguiente(peticion).pipe(
    catchError((error: unknown) => {
      const apiError = normalizarErrorHttp(error);
      const esLogin = peticion.url.includes(RUTA_LOGIN);

      switch (apiError.status) {
        case 401:
          if (esLogin) {
            notificaciones.error(
              'Credenciales inválidas',
              apiError.detalle ?? 'Verifique su correo y contraseña.',
            );
          } else {
            sesion.cerrar();
            notificaciones.error(
              'Sesión expirada',
              'Su sesión ya no es válida. Inicie sesión nuevamente.',
            );
            // Guarda la URL actual para volver a ella después del login.
            const urlActual = router.url;
            if (!urlActual.startsWith('/login')) {
              void router.navigate(['/login'], {
                queryParams: urlActual === '/' ? {} : { returnUrl: urlActual },
                replaceUrl: true,
              });
            }
          }
          break;

        case 403:
          notificaciones.advertencia(
            'Acceso denegado',
            apiError.detalle ?? apiError.mensaje,
          );
          break;

        case 409:
          notificaciones.advertencia(
            'Conflicto',
            apiError.detalle ?? apiError.mensaje,
          );
          break;

        case 422:
          notificaciones.advertencia(
            'Datos inválidos',
            detalleValidacion(apiError.validacion) ??
              apiError.detalle ??
              apiError.mensaje,
          );
          break;

        case 500:
        case 502:
        case 503:
        case 504:
          notificaciones.error(
            'Error del servidor',
            apiError.detalle ?? 'Intente nuevamente en unos minutos.',
          );
          break;

        case 0:
          notificaciones.error(
            'Sin conexión con la API',
            apiError.detalle ?? apiError.mensaje,
          );
          break;

        default:
          notificaciones.error(apiError.mensaje, apiError.detalle);
      }

      return throwError(() => apiError);
    }),
  );
};
