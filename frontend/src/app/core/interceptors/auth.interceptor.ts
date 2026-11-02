import type { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { SessionStore } from '../services/session-store';

const RUTA_LOGIN = '/api/auth/login';

/**
 * Adjunta ``Authorization: Bearer <token>`` a las llamadas a la API.
 *
 * No toca el login (aún no hay token) ni peticiones a otros orígenes.
 */
export const authInterceptor: HttpInterceptorFn = (peticion, siguiente) => {
  const token = inject(SessionStore).token();
  const esApi = peticion.url.startsWith('/api');
  const esLogin = peticion.url.includes(RUTA_LOGIN);

  if (!token || !esApi || esLogin) {
    return siguiente(peticion);
  }

  return siguiente(
    peticion.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    }),
  );
};
