/**
 * Persistencia del token JWT en ``localStorage``.
 *
 * Se aísla del ``SessionStore`` para que los interceptores puedan leer o
 * limpiar el token sin depender de servicios que inyectan ``HttpClient``
 * (evita ciclos de DI).
 */

const CLAVE_TOKEN = 'sigih.token';

function almacen(): Storage | null {
  try {
    return typeof window === 'undefined' ? null : window.localStorage;
  } catch {
    // Navegadores con almacenamiento bloqueado (modo privado estricto).
    return null;
  }
}

/** Devuelve el token guardado o ``null`` si no existe. */
export function leerToken(): string | null {
  return almacen()?.getItem(CLAVE_TOKEN) ?? null;
}

/** Guarda el token emitido por el backend. */
export function guardarToken(token: string): void {
  almacen()?.setItem(CLAVE_TOKEN, token);
}

/** Elimina el token (cierre de sesión o 401). */
export function eliminarToken(): void {
  almacen()?.removeItem(CLAVE_TOKEN);
}
