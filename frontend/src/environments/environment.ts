/**
 * Configuración de DESARROLLO.
 *
 * `apiUrl` es la base de todas las peticiones que hace ApiService.
 * En desarrollo apunta directo a FastAPI (uvicorn) en el puerto 8000.
 * Al usar una URL absoluta, las peticiones NO pasan por proxy.conf.json.
 */
export const environment = {
  production: false,
  apiUrl: 'http://127.0.0.1:8000/api',
};
