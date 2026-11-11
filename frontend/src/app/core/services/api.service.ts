import { HttpClient, HttpParams } from '@angular/common/http';
import type { HttpResponse } from '@angular/common/http';
import { computed, effect, inject, Injectable, signal } from '@angular/core';
import type { Signal, WritableSignal } from '@angular/core';
import { catchError, finalize, map, Observable, of, switchMap, tap, throwError } from 'rxjs';
import type {
  ApiError,
  Area,
  AreaActualizar,
  AreaCrear,
  Categoria,
  CategoriaActualizar,
  CategoriaCrear,
  ConsumoArea,
  EntradaCrear,
  EntradaRegistrada,
  FiltrosMayoresSalidas,
  FiltrosMovimiento,
  FiltrosProducto,
  FiltrosUsuario,
  Lote,
  LoteAlerta,
  MayorSalida,
  MovimientoListado,
  Permiso,
  PermisoAsignado,
  Producto,
  ProductoActualizar,
  ProductoCrear,
  ProductoListado,
  ProductoStockBajo,
  RangoReporte,
  ResumenInventario,
  RespuestaTotal,
  Rol,
  RolActualizar,
  RolCrear,
  SalidaCrear,
  SalidaRegistrada,
  StockValorizado,
  TokenRespuesta,
  Usuario,
  UsuarioActualizar,
  UsuarioAutenticado,
  UsuarioCrear,
  UsuarioPassword,
  UsuarioRol,
} from '../../models';
import { environment } from '../../../environments/environment';
import { normalizarErrorHttp } from '../utils/api-error';
import { SessionStore } from './session-store';

/**
 * Estado de un recurso remoto: datos + carga + error en signals.
 *
 * ``cargado`` permite distinguir una lista vacía "real" de una lista que
 * todavía no se pidió, para no insertar elementos en cachés sin hidratar.
 */
export class Recurso<T> {
  private readonly _datos: WritableSignal<T>;
  private readonly _cargando = signal(false);
  private readonly _error = signal<ApiError | null>(null);
  private readonly _cargado = signal(false);
  private readonly _total = signal(0);

  readonly datos: Signal<T>;
  readonly cargando = this._cargando.asReadonly();
  readonly error = this._error.asReadonly();
  readonly cargado = this._cargado.asReadonly();
  /** Total de coincidencias cuando el listado está paginado. */
  readonly total = this._total.asReadonly();

  constructor(inicial: T) {
    this._datos = signal(inicial);
    this.datos = this._datos.asReadonly();
  }

  /** @internal */
  iniciar(): void {
    this._cargando.set(true);
    this._error.set(null);
  }

  /** @internal */
  completar(datos: T, total?: number): void {
    this._datos.set(datos);
    this._total.set(
      total ?? (Array.isArray(datos) ? datos.length : 0),
    );
    this._cargando.set(false);
    this._error.set(null);
    this._cargado.set(true);
  }

  /** @internal */
  actualizar(transformacion: (actual: T) => T): void {
    this._datos.update(transformacion);
  }

  /** @internal */
  fallar(error: ApiError): void {
    this._error.set(error);
    this._cargando.set(false);
  }

  /** @internal */
  detener(): void {
    this._cargando.set(false);
  }

  /** @internal */
  reiniciar(inicial: T): void {
    this._datos.set(inicial);
    this._total.set(0);
    this._cargando.set(false);
    this._error.set(null);
    this._cargado.set(false);
  }
}

/**
 * Fachada HTTP y de estado reactivo del backend SIGIH.
 *
 * - Las peticiones usan rutas relativas ``/api`` (el proxy de desarrollo las
 *   redirige a FastAPI en ``http://127.0.0.1:8000``).
 * - El token y el usuario viven en ``SessionStore``; el resto del estado de
 *   servidor se cachea en señales por recurso.
 * - Los errores se normalizan a ``ApiError``. El ``ErrorInterceptor`` ya
 *   notifica 401/403/409/500; aquí solo se guarda el error del recurso.
 * - Los listados paginados leen ``X-Total-Count`` y exponen el total en
 *   ``Recurso.total``.
 */
@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.apiUrl;

  readonly sesion = inject(SessionStore);

  readonly estaAutenticado = this.sesion.estaAutenticado;
  readonly usuario = this.sesion.usuario;
  readonly roles = this.sesion.roles;
  readonly permisos = this.sesion.permisos;

  // ---------- Recursos remotos ----------

  readonly categorias = new Recurso<Categoria[]>([]);
  /** Catálogo completo; lo usan los selectores de lotes y reportes. */
  readonly productos = new Recurso<ProductoListado[]>([]);
  /** Página del catálogo de productos; la usa la vista de productos. */
  readonly productosPagina = new Recurso<ProductoListado[]>([]);
  readonly areas = new Recurso<Area[]>([]);
  readonly usuarios = new Recurso<Usuario[]>([]);
  readonly rolesCatalogo = new Recurso<Rol[]>([]);
  readonly permisosCatalogo = new Recurso<Permiso[]>([]);
  readonly movimientos = new Recurso<MovimientoListado[]>([]);
  readonly lotesPorProducto = new Recurso<Record<number, Lote[]>>({});
  readonly stockBajo = new Recurso<ProductoStockBajo[]>([]);
  readonly porVencer = new Recurso<LoteAlerta[]>([]);
  readonly vencidos = new Recurso<LoteAlerta[]>([]);
  readonly resumen = new Recurso<ResumenInventario | null>(null);
  readonly mayoresSalidas = new Recurso<MayorSalida[]>([]);
  readonly consumoPorArea = new Recurso<ConsumoArea[]>([]);
  readonly stockValorizado = new Recurso<StockValorizado[]>([]);

  // ---------- Derivados (computed) ----------

  readonly categoriasActivas = computed(() =>
    this.categorias.datos().filter((categoria) => categoria.activo),
  );

  readonly productosActivos = computed(() =>
    this.productos.datos().filter((producto) => producto.activo),
  );

  readonly areasActivas = computed(() =>
    this.areas.datos().filter((area) => area.activo),
  );

  readonly usuariosActivos = computed(() =>
    this.usuarios.datos().filter((usuario) => usuario.activo),
  );

  readonly rolesActivos = computed(() =>
    this.rolesCatalogo.datos().filter((rol) => rol.activo),
  );

  readonly stockTotal = computed(() =>
    this.productos.datos().reduce((total, producto) => total + producto.stock_total, 0),
  );

  readonly stockDisponibleTotal = computed(() =>
    this.productos
      .datos()
      .reduce((total, producto) => total + producto.stock_disponible, 0),
  );

  readonly totalAlertas = computed(
    () =>
      this.stockBajo.datos().length +
      this.porVencer.datos().length +
      this.vencidos.datos().length,
  );

  readonly hayAlertas = computed(() => this.totalAlertas() > 0);

  readonly valorInventario = computed(() =>
    Number(this.resumen.datos()?.valor_referencial_inventario ?? '0'),
  );

  constructor() {
    // Si el token desaparece (logout o 401), ningún dato de inventario sigue
    // visible en memoria. El efecto corre dentro del contexto de inyección.
    effect(() => {
      if (!this.sesion.estaAutenticado()) {
        this.limpiarCaches();
      }
    });
  }

  /** Lotes ya cargados de un producto; ``[]`` si aún no se pidieron. */
  lotesDe(idProducto: number): Lote[] {
    return this.lotesPorProducto.datos()[idProducto] ?? [];
  }

  /** ``true`` si el usuario tiene el permiso ``modulo:accion``. */
  tienePermiso(codigo: string): boolean {
    return this.sesion.tienePermiso(codigo);
  }

  // ---------- Autenticación ----------

  /** ``true`` si hay un token persistido (la sesión puede restaurarse). */
  hayTokenGuardado(): boolean {
    return this.sesion.token() !== null;
  }

  /**
   * ``POST /api/auth/login`` con formulario OAuth2.
   *
   * Guarda el token y luego hidrata el usuario con ``/auth/me``.
   */
  login(email: string, password: string): Observable<UsuarioAutenticado> {
    const cuerpo = new HttpParams()
      .set('username', email)
      .set('password', password)
      .toString();

    return this.http
      .post<TokenRespuesta>(`${this.base}/auth/login`, cuerpo, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      })
      .pipe(
        tap((respuesta) => this.sesion.establecerToken(respuesta.access_token)),
        switchMap(() => this.obtenerSesion()),
      );
  }

  /** ``GET /api/auth/me``. */
  obtenerSesion(): Observable<UsuarioAutenticado> {
    return this.http
      .get<UsuarioAutenticado>(`${this.base}/auth/me`)
      .pipe(tap((usuario) => this.sesion.establecerUsuario(usuario)));
  }

  /**
   * Restaura la sesión al recargar la página.
   *
   * Solo limpia el token ante 401/403; una caída del backend no debe cerrar
   * la sesión del usuario.
   */
  restaurarSesion(): Observable<UsuarioAutenticado | null> {
    if (!this.sesion.token()) {
      return of(null);
    }

    this.sesion.marcarRestaurando(true);

    return this.http.get<UsuarioAutenticado>(`${this.base}/auth/me`).pipe(
      tap((usuario) => this.sesion.establecerUsuario(usuario)),
      catchError((error: unknown) => {
        const apiError = normalizarErrorHttp(error);
        if (apiError.status === 401 || apiError.status === 403) {
          this.cerrarSesion();
        }
        return of(null);
      }),
      finalize(() => this.sesion.marcarRestaurando(false)),
    );
  }

  /** Cierra la sesión y descarta todas las cachés de datos. */
  cerrarSesion(): void {
    this.sesion.cerrar();
    this.limpiarCaches();
  }

  // ---------- Usuarios ----------

  cargarUsuarios(filtros?: FiltrosUsuario): Observable<Usuario[]> {
    return this.cargarPaginadoEn(
      this.usuarios,
      this.http.get<Usuario[]>(`${this.base}/usuarios`, {
        params: this.parametros(filtros),
        observe: 'response',
      }),
    );
  }

  obtenerUsuario(idUsuario: number): Observable<Usuario> {
    return this.ejecutar(this.http.get<Usuario>(`${this.base}/usuarios/${idUsuario}`));
  }

  crearUsuario(datos: UsuarioCrear): Observable<Usuario> {
    return this.ejecutar(this.http.post<Usuario>(`${this.base}/usuarios`, datos)).pipe(
      tap((creado) => this.insertar(this.usuarios, creado)),
    );
  }

  actualizarUsuario(idUsuario: number, datos: UsuarioActualizar): Observable<Usuario> {
    return this.ejecutar(
      this.http.put<Usuario>(`${this.base}/usuarios/${idUsuario}`, datos),
    ).pipe(tap((actualizado) => this.sustituirUsuario(actualizado)));
  }

  desactivarUsuario(idUsuario: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/usuarios/${idUsuario}`),
    ).pipe(tap(() => this.marcarInactivo(this.usuarios, (u) => u.id_usuario === idUsuario)));
  }

  cambiarPasswordUsuario(idUsuario: number, datos: UsuarioPassword): Observable<void> {
    return this.ejecutar(
      this.http.put<void>(`${this.base}/usuarios/${idUsuario}/password`, datos),
    );
  }

  listarRolesUsuario(idUsuario: number): Observable<Rol[]> {
    return this.ejecutar(this.http.get<Rol[]>(`${this.base}/usuarios/${idUsuario}/roles`));
  }

  listarPermisosUsuario(idUsuario: number): Observable<PermisoAsignado[]> {
    return this.ejecutar(
      this.http.get<PermisoAsignado[]>(`${this.base}/usuarios/${idUsuario}/permisos`),
    );
  }

  asignarRolUsuario(idUsuario: number, datos: UsuarioRol): Observable<void> {
    return this.ejecutar(
      this.http.post<void>(`${this.base}/usuarios/${idUsuario}/roles`, datos),
    );
  }

  quitarRolUsuario(idUsuario: number, idRol: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/usuarios/${idUsuario}/roles/${idRol}`),
    );
  }

  // ---------- Roles y permisos ----------

  cargarRoles(soloActivos?: boolean | null): Observable<Rol[]> {
    return this.cargarEn(
      this.rolesCatalogo,
      this.http.get<Rol[]>(`${this.base}/roles`, {
        params: this.parametros({ solo_activos: soloActivos }),
      }),
    );
  }

  obtenerRol(idRol: number): Observable<Rol> {
    return this.ejecutar(this.http.get<Rol>(`${this.base}/roles/${idRol}`));
  }

  crearRol(datos: RolCrear): Observable<Rol> {
    return this.ejecutar(this.http.post<Rol>(`${this.base}/roles`, datos)).pipe(
      tap((creado) => this.insertar(this.rolesCatalogo, creado)),
    );
  }

  actualizarRol(idRol: number, datos: RolActualizar): Observable<Rol> {
    return this.ejecutar(
      this.http.put<Rol>(`${this.base}/roles/${idRol}`, datos),
    ).pipe(tap((actualizado) => this.sustituir(this.rolesCatalogo, (r) => r.id_rol === idRol, actualizado)));
  }

  desactivarRol(idRol: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/roles/${idRol}`),
    ).pipe(tap(() => this.marcarInactivo(this.rolesCatalogo, (r) => r.id_rol === idRol)));
  }

  listarPermisosRol(idRol: number): Observable<Permiso[]> {
    return this.ejecutar(
      this.http.get<Permiso[]>(`${this.base}/roles/${idRol}/permisos`),
    );
  }

  sincronizarPermisosRol(idRol: number, permisos: string[]): Observable<RespuestaTotal> {
    return this.ejecutar(
      this.http.put<RespuestaTotal>(`${this.base}/roles/${idRol}/permisos`, { permisos }),
    ).pipe(
      tap((respuesta) => {
        if (!this.rolesCatalogo.cargado()) {
          return;
        }
        this.rolesCatalogo.actualizar((lista) =>
          lista.map((rol) =>
            rol.id_rol === idRol ? { ...rol, total_permisos: respuesta.total } : rol,
          ),
        );
      }),
    );
  }

  asignarPermisoRol(idRol: number, idPermiso: number): Observable<void> {
    return this.ejecutar(
      this.http.post<void>(`${this.base}/roles/${idRol}/permisos/${idPermiso}`, null),
    );
  }

  quitarPermisoRol(idRol: number, idPermiso: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/roles/${idRol}/permisos/${idPermiso}`),
    );
  }

  cargarPermisos(modulo?: string | null): Observable<Permiso[]> {
    return this.cargarEn(
      this.permisosCatalogo,
      this.http.get<Permiso[]>(`${this.base}/permisos`, {
        params: this.parametros({ modulo }),
      }),
    );
  }

  obtenerPermiso(idPermiso: number): Observable<Permiso> {
    return this.ejecutar(this.http.get<Permiso>(`${this.base}/permisos/${idPermiso}`));
  }

  // ---------- Áreas ----------

  cargarAreas(soloActivos?: boolean | null): Observable<Area[]> {
    return this.cargarEn(
      this.areas,
      this.http.get<Area[]>(`${this.base}/areas`, {
        params: this.parametros({ solo_activos: soloActivos }),
      }),
    );
  }

  obtenerArea(idArea: number): Observable<Area> {
    return this.ejecutar(this.http.get<Area>(`${this.base}/areas/${idArea}`));
  }

  crearArea(datos: AreaCrear): Observable<Area> {
    return this.ejecutar(this.http.post<Area>(`${this.base}/areas`, datos)).pipe(
      tap((creada) => this.insertar(this.areas, creada)),
    );
  }

  actualizarArea(idArea: number, datos: AreaActualizar): Observable<Area> {
    return this.ejecutar(
      this.http.put<Area>(`${this.base}/areas/${idArea}`, datos),
    ).pipe(
      tap((actualizada) =>
        this.sustituir(this.areas, (area) => area.id_area === idArea, actualizada),
      ),
    );
  }

  desactivarArea(idArea: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/areas/${idArea}`),
    ).pipe(tap(() => this.marcarInactivo(this.areas, (area) => area.id_area === idArea)));
  }

  // ---------- Categorías ----------

  cargarCategorias(soloActivos?: boolean | null): Observable<Categoria[]> {
    return this.cargarEn(
      this.categorias,
      this.http.get<Categoria[]>(`${this.base}/categorias`, {
        params: this.parametros({ solo_activos: soloActivos }),
      }),
    );
  }

  obtenerCategoria(idCategoria: number): Observable<Categoria> {
    return this.ejecutar(
      this.http.get<Categoria>(`${this.base}/categorias/${idCategoria}`),
    );
  }

  crearCategoria(datos: CategoriaCrear): Observable<Categoria> {
    return this.ejecutar(
      this.http.post<Categoria>(`${this.base}/categorias`, datos),
    ).pipe(tap((creada) => this.insertar(this.categorias, creada)));
  }

  actualizarCategoria(
    idCategoria: number,
    datos: CategoriaActualizar,
  ): Observable<Categoria> {
    return this.ejecutar(
      this.http.put<Categoria>(`${this.base}/categorias/${idCategoria}`, datos),
    ).pipe(
      tap((actualizada) =>
        this.sustituir(this.categorias, (c) => c.id_categoria === idCategoria, actualizada),
      ),
    );
  }

  desactivarCategoria(idCategoria: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/categorias/${idCategoria}`),
    ).pipe(
      tap(() =>
        this.marcarInactivo(this.categorias, (c) => c.id_categoria === idCategoria),
      ),
    );
  }

  // ---------- Productos ----------

  cargarProductos(filtros?: FiltrosProducto): Observable<ProductoListado[]> {
    const usados = filtros ?? this.filtrosProductos;
    this.filtrosProductos = usados;
    return this.cargarEn(
      this.productos,
      this.http.get<ProductoListado[]>(`${this.base}/productos`, {
        params: this.parametros(usados),
      }),
    );
  }

  /** Página del catálogo de productos, con filtros y ``X-Total-Count``. */
  cargarProductosPagina(
    filtros: FiltrosProducto = {},
  ): Observable<ProductoListado[]> {
    this.filtrosProductosPagina = filtros;
    return this.cargarPaginadoEn(
      this.productosPagina,
      this.http.get<ProductoListado[]>(`${this.base}/productos`, {
        params: this.parametros(filtros),
        observe: 'response',
      }),
    );
  }

  obtenerProducto(idProducto: number): Observable<Producto> {
    return this.ejecutar(
      this.http.get<Producto>(`${this.base}/productos/${idProducto}`),
    );
  }

  crearProducto(datos: ProductoCrear): Observable<Producto> {
    return this.ejecutar(
      this.http.post<Producto>(`${this.base}/productos`, datos),
    ).pipe(tap(() => this.refrescarProductosSiCargados()));
  }

  actualizarProducto(
    idProducto: number,
    datos: ProductoActualizar,
  ): Observable<Producto> {
    return this.ejecutar(
      this.http.put<Producto>(`${this.base}/productos/${idProducto}`, datos),
    ).pipe(
      tap((actualizado) => {
        if (!this.productos.cargado()) {
          return;
        }
        this.productos.actualizar((lista) =>
          lista.map((producto) =>
            producto.id_producto === idProducto
              ? { ...producto, ...actualizado }
              : producto,
          ),
        );
      }),
    );
  }

  desactivarProducto(idProducto: number): Observable<void> {
    return this.ejecutar(
      this.http.delete<void>(`${this.base}/productos/${idProducto}`),
    ).pipe(
      tap(() =>
        this.marcarInactivo(this.productos, (p) => p.id_producto === idProducto),
      ),
    );
  }

  // ---------- Lotes ----------

  cargarLotes(idProducto: number): Observable<Lote[]> {
    return this.ejecutar(
      this.http.get<Lote[]>(`${this.base}/productos/${idProducto}/lotes`),
    ).pipe(
      tap((lotes) =>
        this.lotesPorProducto.actualizar((mapa) => ({
          ...mapa,
          [idProducto]: lotes,
        })),
      ),
    );
  }

  // ---------- Movimientos ----------

  cargarMovimientos(filtros?: FiltrosMovimiento): Observable<MovimientoListado[]> {
    const usados = filtros ?? this.filtrosMovimientos;
    this.filtrosMovimientos = usados;
    return this.cargarPaginadoEn(
      this.movimientos,
      this.http.get<MovimientoListado[]>(`${this.base}/movimientos`, {
        params: this.parametros(usados),
        observe: 'response',
      }),
    );
  }

  /**
   * Consulta movimientos sin modificar la caché compartida ni los filtros
   * recordados. La usa el kardex de reportes para no alterar la página de
   * movimientos.
   */
  consultarMovimientos(filtros: FiltrosMovimiento): Observable<MovimientoListado[]> {
    return this.ejecutar(
      this.http.get<MovimientoListado[]>(`${this.base}/movimientos`, {
        params: this.parametros(filtros),
      }),
    );
  }

  /** Catálogo de motivos de entrada publicado por el backend. */
  cargarMotivosEntrada(): Observable<string[]> {
    return this.ejecutar(
      this.http.get<string[]>(`${this.base}/movimientos/motivos-entrada`),
    );
  }

  registrarEntrada(datos: EntradaCrear): Observable<EntradaRegistrada> {
    return this.ejecutar(
      this.http.post<EntradaRegistrada>(`${this.base}/movimientos/entradas`, datos),
    ).pipe(tap(() => this.refrescarTrasMovimiento(datos.id_producto)));
  }

  registrarSalida(datos: SalidaCrear): Observable<SalidaRegistrada> {
    return this.ejecutar(
      this.http.post<SalidaRegistrada>(`${this.base}/movimientos/salidas`, datos),
    ).pipe(tap(() => this.refrescarTrasMovimiento(datos.id_producto)));
  }

  // ---------- Alertas y dashboard ----------

  cargarStockBajo(): Observable<ProductoStockBajo[]> {
    return this.cargarEn(
      this.stockBajo,
      this.http.get<ProductoStockBajo[]>(`${this.base}/alertas/stock-bajo`),
    );
  }

  cargarPorVencer(dias = this.diasPorVencer): Observable<LoteAlerta[]> {
    this.diasPorVencer = dias;
    return this.cargarEn(
      this.porVencer,
      this.http.get<LoteAlerta[]>(`${this.base}/alertas/por-vencer`, {
        params: this.parametros({ dias }),
      }),
    );
  }

  cargarVencidos(): Observable<LoteAlerta[]> {
    return this.cargarEn(
      this.vencidos,
      this.http.get<LoteAlerta[]>(`${this.base}/alertas/vencidos`),
    );
  }

  /** ``GET /api/dashboard/resumen``. */
  cargarResumen(desde?: string | null, hasta?: string | null): Observable<ResumenInventario> {
    if (desde !== undefined || hasta !== undefined) {
      this.rangoResumen = { desde: desde ?? null, hasta: hasta ?? null };
    }

    this.resumen.iniciar();
    return this.http
      .get<ResumenInventario>(`${this.base}/dashboard/resumen`, {
        params: this.parametros(this.rangoResumen),
      })
      .pipe(
        tap((datos) => this.resumen.completar(datos)),
        catchError((error: unknown) => {
          const apiError = normalizarErrorHttp(error);
          this.resumen.fallar(apiError);
          return throwError(() => apiError);
        }),
        finalize(() => this.resumen.detener()),
      );
  }

  // ---------- Reportes ----------

  cargarMayoresSalidas(filtros: FiltrosMayoresSalidas): Observable<MayorSalida[]> {
    return this.cargarEn(
      this.mayoresSalidas,
      this.http.get<MayorSalida[]>(`${this.base}/reportes/mayores-salidas`, {
        params: this.parametros(filtros),
      }),
    );
  }

  cargarConsumoPorArea(rango: RangoReporte): Observable<ConsumoArea[]> {
    return this.cargarEn(
      this.consumoPorArea,
      this.http.get<ConsumoArea[]>(`${this.base}/reportes/consumo-por-area`, {
        params: this.parametros(rango),
      }),
    );
  }

  cargarStockValorizado(): Observable<StockValorizado[]> {
    return this.cargarEn(
      this.stockValorizado,
      this.http.get<StockValorizado[]>(`${this.base}/reportes/stock-valorizado`),
    );
  }

  // ---------- Internos ----------

  private filtrosProductos: FiltrosProducto = {};
  private filtrosProductosPagina: FiltrosProducto = {};
  private filtrosMovimientos: FiltrosMovimiento = {};
  private rangoResumen: { desde?: string | null; hasta?: string | null } = {};
  private diasPorVencer = 30;

  private parametros(filtros: object = {}): HttpParams {
    let params = new HttpParams();
    for (const [clave, valor] of Object.entries(filtros)) {
      if (valor === null || valor === undefined || valor === '') {
        continue;
      }
      params = params.set(clave, String(valor));
    }
    return params;
  }

  private cargarEn<T>(recurso: Recurso<T>, peticion: Observable<T>): Observable<T> {
    recurso.iniciar();
    return peticion.pipe(
      tap((datos) => recurso.completar(datos)),
      catchError((error: unknown) => {
        const apiError = normalizarErrorHttp(error);
        recurso.fallar(apiError);
        return throwError(() => apiError);
      }),
      finalize(() => recurso.detener()),
    );
  }

  private cargarPaginadoEn<T>(
    recurso: Recurso<T[]>,
    peticion: Observable<HttpResponse<T[]>>,
  ): Observable<T[]> {
    recurso.iniciar();
    return peticion.pipe(
      tap((respuesta) => {
        const datos = respuesta.body ?? [];
        const cabecera = respuesta.headers.get('X-Total-Count');
        const total = cabecera === null ? datos.length : Number(cabecera);
        recurso.completar(datos, Number.isFinite(total) ? total : datos.length);
      }),
      map((respuesta) => respuesta.body ?? []),
      catchError((error: unknown) => {
        const apiError = normalizarErrorHttp(error);
        recurso.fallar(apiError);
        return throwError(() => apiError);
      }),
      finalize(() => recurso.detener()),
    );
  }

  private ejecutar<T>(peticion: Observable<T>): Observable<T> {
    return peticion.pipe(
      catchError((error: unknown) => throwError(() => normalizarErrorHttp(error))),
    );
  }

  private insertar<T>(recurso: Recurso<T[]>, elemento: T): void {
    if (!recurso.cargado()) {
      return;
    }
    recurso.actualizar((lista) => [...lista, elemento]);
  }

  private sustituir<T>(recurso: Recurso<T[]>, coincide: (item: T) => boolean, nuevo: T): void {
    if (!recurso.cargado()) {
      return;
    }
    recurso.actualizar((lista) => lista.map((item) => (coincide(item) ? nuevo : item)));
  }

  private marcarInactivo<T extends { activo: boolean }>(
    recurso: Recurso<T[]>,
    coincide: (item: T) => boolean,
  ): void {
    if (!recurso.cargado()) {
      return;
    }
    recurso.actualizar((lista) =>
      lista.map((item) => (coincide(item) ? { ...item, activo: false } : item)),
    );
  }

  private sustituirUsuario(actualizado: Usuario): void {
    this.sustituir(
      this.usuarios,
      (usuario) => usuario.id_usuario === actualizado.id_usuario,
      actualizado,
    );
  }

  private refrescarProductosSiCargados(): void {
    if (this.productos.cargado()) {
      this.cargarProductos().subscribe({ error: () => undefined });
    }
    if (this.productosPagina.cargado()) {
      this.cargarProductosPagina(this.filtrosProductosPagina).subscribe({
        error: () => undefined,
      });
    }
  }

  private refrescarTrasMovimiento(idProducto: number): void {
    this.refrescarProductosSiCargados();
    this.cargarLotes(idProducto).subscribe({ error: () => undefined });

    if (this.movimientos.cargado()) {
      this.cargarMovimientos().subscribe({ error: () => undefined });
    }
    if (this.stockBajo.cargado()) {
      this.cargarStockBajo().subscribe({ error: () => undefined });
    }
    if (this.porVencer.cargado()) {
      this.cargarPorVencer().subscribe({ error: () => undefined });
    }
    if (this.vencidos.cargado()) {
      this.cargarVencidos().subscribe({ error: () => undefined });
    }
    if (this.resumen.cargado()) {
      this.cargarResumen().subscribe({ error: () => undefined });
    }
  }

  private limpiarCaches(): void {
    this.categorias.reiniciar([]);
    this.productos.reiniciar([]);
    this.productosPagina.reiniciar([]);
    this.areas.reiniciar([]);
    this.usuarios.reiniciar([]);
    this.rolesCatalogo.reiniciar([]);
    this.permisosCatalogo.reiniciar([]);
    this.movimientos.reiniciar([]);
    this.lotesPorProducto.reiniciar({});
    this.stockBajo.reiniciar([]);
    this.porVencer.reiniciar([]);
    this.vencidos.reiniciar([]);
    this.resumen.reiniciar(null);
    this.mayoresSalidas.reiniciar([]);
    this.consumoPorArea.reiniciar([]);
    this.stockValorizado.reiniciar([]);
  }
}
