import { computed, inject, Injectable, signal } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, finalize, Observable, of, Subject, take, tap, throwError } from 'rxjs';
import type { ApiError, UsuarioAutenticado } from '../../models';
import { normalizarErrorHttp } from '../utils/api-error';
import { ApiService } from './api.service';
import { NotificacionService } from './notificacion.service';
import { SessionStore } from './session-store';

/**
 * Fachada de autenticación basada en signals.
 *
 * ``SessionStore`` conserva el token y el usuario (para que los interceptores
 * puedan leerlos sin depender de ``HttpClient``); ``AuthService`` expone esos
 * datos como estado reactivo de alto nivel y centraliza el login, el logout,
 * la restauración de sesión y la comprobación de permisos.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly api = inject(ApiService);
  private readonly sesion = inject(SessionStore);
  private readonly router = inject(Router);
  private readonly notificaciones = inject(NotificacionService);

  private readonly _cargando = signal(false);
  private readonly _error = signal<string | null>(null);
  private readonly _restauracionCompletada = new Subject<void>();

  /** ``true`` mientras se envía el formulario de login. */
  readonly cargando = this._cargando.asReadonly();
  /** Último error de autenticación legible para la UI. */
  readonly error = this._error.asReadonly();

  // ---------- Estado de sesión ----------

  readonly token = this.sesion.token;
  readonly usuario = this.sesion.usuario;
  readonly restaurando = this.sesion.restaurando;
  readonly roles = this.sesion.roles;
  readonly permisos = this.sesion.permisos;

  /** El token existe (la sesión puede restaurarse). */
  readonly isAutenticado = this.sesion.estaAutenticado;

  /** Rol principal del usuario, o ``null`` si aún no hay sesión. */
  readonly rolActual = computed<string | null>(() => this.roles()[0] ?? null);

  /** ``true`` si el usuario tiene el rol ADMINISTRADOR. */
  readonly esAdmin = this.sesion.esAdministrador;

  /** Mapa de permisos efectivos para consultas O(1) desde la UI. */
  readonly permisosMap = computed<ReadonlyMap<string, true>>(
    () => new Map(this.permisos().map((permiso) => [permiso, true] as const)),
  );

  readonly nombre = computed(() => this.usuario()?.nombre ?? 'Usuario SIGIH');
  readonly email = computed(() => this.usuario()?.email ?? '');
  readonly iniciales = computed(() => {
    const nombre = this.nombre().trim();
    if (!nombre) {
      return 'SG';
    }
    const partes = nombre.split(/\s+/).filter(Boolean);
    if (partes.length === 1) {
      return partes[0].slice(0, 2).toUpperCase();
    }
    return `${partes[0][0]}${partes.at(-1)?.[0] ?? ''}`.toUpperCase();
  });

  /** Ruta de inicio recomendada según el rol del usuario. */
  readonly rutaInicio = computed(() => this.rutaInicioPara(this.usuario()));

  // ---------- API ----------

  /**
   * Inicia sesión y guarda el token + usuario en el estado global.
   *
   * El observable emite el usuario hidratado por ``GET /api/auth/me``.
   */
  login(email: string, password: string): Observable<UsuarioAutenticado> {
    this._cargando.set(true);
    this._error.set(null);

    return this.api.login(email.trim(), password).pipe(
      tap(() => this._cargando.set(false)),
      catchError((error: unknown) => {
        const apiError = normalizarErrorHttp(error);
        this._error.set(this.mensajeError(apiError));
        this._cargando.set(false);
        return throwError(() => apiError);
      }),
    );
  }

  /**
   * Cierra la sesión, limpia las cachés y (por defecto) vuelve al login.
   */
  logout(redirigir = true): void {
    this.api.cerrarSesion();
    this._error.set(null);
    this._cargando.set(false);

    if (redirigir) {
      void this.router.navigate(['/login'], { replaceUrl: true });
    }
  }

  /** Alias explícito de ``logout()``. */
  cerrarSesion(redirigir = true): void {
    this.logout(redirigir);
  }

  /**
   * Restaura la sesión desde el token guardado en ``localStorage``.
   *
   * Es no bloqueante: si la API no responde, la aplicación sigue arrancando.
   * Solo se descarta el token ante 401/403 (lo decide ``ApiService``).
   */
  restaurarSesion(): Observable<UsuarioAutenticado | null> {
    if (!this.token()) {
      return of(null);
    }

    return this.api.restaurarSesion().pipe(
      finalize(() => this._restauracionCompletada.next()),
    );
  }

  /**
   * Espera a que termine la restauración de sesión en curso.
   *
   * Los guards lo usan para no decidir con un estado a medio hidratar tras
   * una recarga del navegador.
   */
  esperarRestauracion(): Observable<void> {
    if (!this.restaurando()) {
      return of(undefined);
    }
    return this._restauracionCompletada.pipe(take(1));
  }

  // ---------- Permisos ----------

  /** ``true`` si el usuario tiene el permiso ``modulo:accion``. */
  tienePermiso(permiso: string): boolean {
    return this.permisosMap().has(permiso);
  }

  /** ``true`` si el usuario tiene al menos uno de los permisos. */
  tieneAlguno(permisos: readonly string[]): boolean {
    const mapa = this.permisosMap();
    return permisos.some((permiso) => mapa.has(permiso));
  }

  /** ``true`` si el usuario tiene todos los permisos. */
  tieneTodos(permisos: readonly string[]): boolean {
    const mapa = this.permisosMap();
    return permisos.every((permiso) => mapa.has(permiso));
  }

  /** ``true`` si el usuario tiene el rol indicado. */
  tieneRol(rol: string): boolean {
    return this.roles().includes(rol);
  }

  /**
   * Ruta de inicio según el rol principal.
   *
   * - ADMINISTRADOR → dashboard
   * - ALMACEN → movimientos
   * - CONSULTA → productos
   */
  rutaInicioPara(usuario: UsuarioAutenticado | null = this.usuario()): string {
    if (!usuario) {
      return '/login';
    }
    if (usuario.roles.includes('ADMINISTRADOR')) {
      return '/dashboard';
    }
    if (usuario.roles.includes('ALMACEN')) {
      return '/movimientos';
    }
    if (usuario.roles.includes('CONSULTA')) {
      return '/productos';
    }
    return '/dashboard';
  }

  /** Aviso informativo (por ejemplo, sesión restaurada correctamente). */
  notificarSesion(mensaje: string, detalle?: string): void {
    this.notificaciones.info(mensaje, detalle);
  }

  // ---------- Internos ----------

  private mensajeError(error: ApiError): string {
    const detalle = error.detalle?.trim();
    return detalle && detalle !== error.mensaje
      ? `${error.mensaje}: ${detalle}`
      : error.mensaje;
  }
}
