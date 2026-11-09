import { computed, Injectable, signal } from '@angular/core';
import type { UsuarioAutenticado } from '../../models';
import { eliminarToken, guardarToken, leerToken } from './token-storage';

/**
 * Estado reactivo de la sesión (token + usuario autenticado).
 *
 * No inyecta ``HttpClient``: los interceptores y el ``ApiService`` pueden
 * consumirlo sin crear dependencias circulares. El usuario se hidrata con
 * ``GET /api/auth/me``, porque el token solo transporta el correo.
 */
@Injectable({ providedIn: 'root' })
export class SessionStore {
  private readonly _token = signal<string | null>(leerToken());
  private readonly _usuario = signal<UsuarioAutenticado | null>(null);
  private readonly _restaurando = signal(false);

  readonly token = this._token.asReadonly();
  readonly usuario = this._usuario.asReadonly();
  readonly restaurando = this._restaurando.asReadonly();

  readonly estaAutenticado = computed(() => this._token() !== null);
  readonly roles = computed<readonly string[]>(() => this._usuario()?.roles ?? []);
  readonly permisos = computed<readonly string[]>(() => this._usuario()?.permisos ?? []);
  readonly esAdministrador = computed(() => this.roles().includes('ADMINISTRADOR'));

  /** ``true`` si el usuario tiene el permiso ``modulo:accion``. */
  tienePermiso(codigo: string): boolean {
    return this.permisos().includes(codigo);
  }

  /** ``true`` si tiene al menos uno de los permisos indicados. */
  tieneAlguno(codigos: readonly string[]): boolean {
    const actuales = this.permisos();
    return codigos.some((codigo) => actuales.includes(codigo));
  }

  /** ``true`` si tiene todos los permisos indicados. */
  tieneTodos(codigos: readonly string[]): boolean {
    const actuales = this.permisos();
    return codigos.every((codigo) => actuales.includes(codigo));
  }

  /** Guarda el token y lo refleja en el signal. */
  establecerToken(token: string): void {
    guardarToken(token);
    this._token.set(token);
  }

  /** Fija el usuario devuelto por ``/auth/me``. */
  establecerUsuario(usuario: UsuarioAutenticado | null): void {
    this._usuario.set(usuario);
  }

  /** Marca si hay una restauración de sesión en curso. */
  marcarRestaurando(valor: boolean): void {
    this._restaurando.set(valor);
  }

  /** Limpia token, usuario y almacenamiento local. */
  cerrar(): void {
    eliminarToken();
    this._token.set(null);
    this._usuario.set(null);
    this._restaurando.set(false);
  }
}
