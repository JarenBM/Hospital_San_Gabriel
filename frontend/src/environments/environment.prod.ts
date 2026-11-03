/**
 * Configuración de PRODUCCIÓN.
 *
 * Se usa automáticamente al ejecutar `npm run build` gracias al
 * fileReplacements de angular.json.
 *
 * `/api` es relativo: en producción se espera un reverse proxy
 * (IIS/Nginx) que redirija /api hacia FastAPI en el mismo dominio.
 * Si el API vive en otro dominio, reemplazar por la URL real.
 */
export const environment = {
  production: true,
  apiUrl: '/api',
};
