import type { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { environment } from '../../../environments/environment';
import { SessionStore } from '../services/session-store';

const API = environment.apiUrl;
const RUTA_LOGIN = '/api/auth/login';

/**
 * Adjunta ``Authorization: Bearer <token>`` a las llamadas a la API.
 *
 * No toca el login (aún no hay token) ni peticiones a otros orígenes.
 */
export const authInterceptor: HttpInterceptorFn = (peticion, siguiente) => {
  const token = inject(SessionStore).token();
  // `environment.apiUrl` puede ser relativo (`/api`) o absoluto
  // (`http://127.0.0.1:8000/api`), según la configuración del build.
  const esApi = peticion.url === API || peticion.url.startsWith(`${API}/`);
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
