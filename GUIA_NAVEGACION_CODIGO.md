# GUÍA DE NAVEGACIÓN DEL CÓDIGO — SIGIH

**Sistema:** SIGIH — Sistema de Gestión de Inventario Hospitalario
**Propósito:** responder preguntas de navegación directa del código (“¿en qué archivo está…?”, “¿dónde se llama la API?”, “¿qué SP procesa esta pantalla?”).
**Rama:** `rediseno_visual`
**Líneas verificadas:** 2026-11-11 sobre el código fuente actual.

> **Cómo leer las líneas:** todas las referencias son `archivo:línea`. Si el archivo se edita, los números pueden desplazarse; el nombre de la función o del `sp_*` siempre es la referencia estable.

---

## Índice

1. [Mapa de capas](#1-mapa-de-capas)
2. [Rutas Angular](#2-rutas-angular)
3. [Resumen de los 10 módulos](#3-resumen-de-los-10-módulos)
4. [Fichas por módulo](#4-fichas-por-módulo)
   - [Ficha 1 — Autenticación](#ficha-1--autenticación-login)
   - [Ficha 2 — Dashboard](#ficha-2--dashboard)
   - [Ficha 3 — Categorías](#ficha-3--categorías)
   - [Ficha 4 — Áreas Hospitalarias](#ficha-4--áreas-hospitalarias)
   - [Ficha 5 — Productos](#ficha-5--productos)
   - [Ficha 6 — Lotes](#ficha-6--lotes)
   - [Ficha 7 — Movimientos](#ficha-7--movimientos-entradas-y-salidas)
   - [Ficha 8 — Alertas](#ficha-8--alertas)
   - [Ficha 9 — Reportes / Kardex](#ficha-9--reportes--kardex)
   - [Ficha 10 — Usuarios y Roles](#ficha-10--usuarios-y-roles)
5. [Anexo A — Catálogo de Stored Procedures](#anexo-a--catálogo-de-stored-procedures)
6. [Anexo B — Códigos de error de negocio](#anexo-b--códigos-de-error-de-negocio)
7. [Anexo C — 20 preguntas rápidas de repaso](#anexo-c--20-preguntas-rápidas-de-repaso)
8. [Anexo D — Verificación rápida](#anexo-d--verificación-rápida)

---

## 1. Mapa de capas

### 1.1 Flujo general

```
┌──────────────────────────────────────────────────────────────────────┐
│ FRONTEND (Angular 21)                                                │
│                                                                      │
│  features/<modulo>/<modulo>.ts      ← signals + métodos de pantalla  │
│  features/<modulo>/<modulo>.html    ← formulario / tabla / modal     │
│  features/<modulo>/<modulo>.scss    ← estilos del módulo             │
│                    │                                                 │
│                    │ inject(ApiService) / inject(AuthService)        │
│                    ▼                                                 │
│  core/services/api.service.ts       ← HTTP + estado Recurso<T>       │
│  core/services/auth.service.ts      ← sesión, login, permisos        │
│                    │                                                 │
│                    │ HttpClient (interceptor agrega Bearer)          │
└────────────────────┼─────────────────────────────────────────────────┘
                     │  HTTP /api/...
┌────────────────────▼─────────────────────────────────────────────────┐
│ BACKEND (FastAPI)                                                    │
│                                                                      │
│  apis/<modulo>_api.py        ← @router.get/post/put/delete           │
│                    │                                                 │
│                    ▼                                                 │
│  services/<modulo>_service.py ← reglas de negocio, arma los modelos  │
│                    │                                                 │
│                    ▼                                                 │
│  repositories/<modulo>_repository.py ← ejecuta el SP vía pyodbc      │
│  repositories/base.py                ← EXEC parametrizado            │
│  repositories/procedimientos.py      ← catálogo/lista blanca de SP   │
│                    │                                                 │
│                    │ EXEC dbo.sp_...                                 │
└────────────────────▼─────────────────────────────────────────────────┘
┌────────────────────▼─────────────────────────────────────────────────┐
│ BASE DE DATOS (SQL Server, base SIGIH)                               │
│  database/0X_sp_<modulo>.sql  ← CREATE OR ALTER PROCEDURE dbo.sp_... │
│  database/INSTALAR_SIGIH.sql  ← instalador consolidado               │
└──────────────────────────────────────────────────────────────────────┘
```

**Regla de arquitectura que el docente puede preguntar:** un `api` **no** llama a un `repository` directamente; siempre pasa por `services`. Los `services` y `apis` no conocen `pyodbc`; solo los `repositories` ejecutan SP.

### 1.2 Ejemplo completo: registrar una salida de inventario

```
[HTML] movimientos.html:455   <form (submit)="enviarSalida($event)">
   │
   ▼
[TS] movimientos.ts:464       enviarSalida()
   │  lee signals: idProductoSalida, idLoteSalida, idAreaSalida,
   │  cantidadSalida, motivoSalida
   ▼
[TS] movimientos.ts:487       this.api.registrarSalida({...})
   │
   ▼
[SERVICE ANGULAR] api.service.ts:650   registrarSalida()
   │  POST `${base}/movimientos/salidas`
   ▼
[FASTAPI] movimiento_api.py:83-86      @router.post("/salidas") → crear_salida()
   │  usuario = token (Depends(SALIDA)); id_usuario NO viene del body
   ▼
[SERVICE PYTHON] movimiento_service.py:54   registrar_salida()
   │
   ▼
[REPOSITORY] movimiento_repository.py:75    registrar_salida()
   │  EXEC dbo.sp_Movimientos_RegistrarSalida ...
   ▼
[SP] database/08_sp_movimientos.sql:152     dbo.sp_Movimientos_RegistrarSalida
   │  BEGIN TRAN + XACT_ABORT
   │  si @id_lote es NULL → FEFO (lote vigente con vencimiento más próximo)
   │  valida stock (51209), vencimiento <= hoy (51208)
   │  actualiza Lotes + inserta Movimientos + inserta Auditoria
   │  COMMIT
   ▼
[RESPUESTA] { id_movimiento, id_lote, numero_lote, stock_anterior, stock_posterior }
```

### 1.3 Servicios y estado compartido

| Pieza | Archivo | Qué hace |
|---|---|---|
| `ApiService` | `frontend/src/app/core/services/api.service.ts` | Único servicio HTTP de todos los módulos. Mantiene los `Recurso<T>` con signals. |
| `Recurso<T>` | `api.service.ts:67-112` | Contenedor con `cargando`, `error`, `cargado`, `total`, `datos` y métodos `iniciar/completar/fallar`. |
| Recursos globales | `api.service.ts:147-164` | `categorias`, `productos`, `areas`, `usuarios`, `rolesCatalogo`, `permisosCatalogo`, `movimientos`, `lotesPorProducto`, `stockBajo`, `porVencer`, `vencidos`, `resumen`, `mayoresSalidas`, `consumoPorArea`, `stockValorizado`. |
| `AuthService` | `frontend/src/app/core/services/auth.service.ts` | Login (`:80`), sesión, roles/permisos (`tienePermiso` `:145`) y ruta inicial por rol (`rutaInicioPara` `:173`). |
| `SessionStore` | `frontend/src/app/core/services/session-store.ts` | Persiste token/usuario y expone signals de sesión. |
| Interceptor | `frontend/src/app/core/interceptors/auth.interceptor.ts` | Agrega `Authorization: Bearer <token>`. |
| Guards | `frontend/src/app/core/guards/auth.guard.ts`, `role.guard.ts`, `guest.guard.ts` | Protegen rutas; `role.guard.ts` valida permisos de la ruta. |

---

## 2. Rutas Angular

Archivo: `frontend/src/app/app.routes.ts`

| Ruta | Línea | Componente |
|---|---|---|
| `/login` | 17 | `features/auth/login/login.ts` (`guestGuard`) |
| `/403` | 24 | `features/errors/forbidden/forbidden.ts` |
| `/404` | 32 | `features/errors/not-found/not-found.ts` |
| `/dashboard` | 52 | `features/dashboard/dashboard.ts` |
| `/productos` | 62 | `features/productos/productos.ts` |
| `/categorias` | 72 | `features/categorias/categorias.ts` |
| `/lotes` | 82 | `features/lotes/lotes.ts` |
| `/movimientos` | 90 | `features/movimientos/movimientos.ts` |
| `/alertas` | 100 | `features/alertas/alertas.ts` |
| `/reportes` | 108 | `features/reportes/reportes.ts` |
| `/areas` | 118 | `features/areas/areas.ts` |
| `/usuarios` | 126 | `features/usuarios/usuarios.ts` |
| `/roles` | 136 | `features/roles/roles.ts` |

Todas las rutas internas usan `authGuard` (`:41`) y `roleGuard` (`canActivate` en cada ruta). El comodín `**` redirige a `/404` (`:143`).

---

## 3. Resumen de los 10 módulos

| # | Módulo | Componente TS | Endpoint base | SP principal |
|---|---|---|---|---|
| 1 | Autenticación | `features/auth/login/login.ts` | `/api/auth` | `sp_Usuarios_ObtenerSesion` |
| 2 | Dashboard | `features/dashboard/dashboard.ts` | `/api/dashboard` | `sp_Dashboard_Resumen` |
| 3 | Categorías | `features/categorias/categorias.ts` | `/api/categorias` | `sp_Categorias_*` |
| 4 | Áreas | `features/areas/areas.ts` | `/api/areas` | `sp_Areas_*` |
| 5 | Productos | `features/productos/productos.ts` | `/api/productos` | `sp_Productos_*` |
| 6 | Lotes | `features/lotes/lotes.ts` | `/api/productos/{id}/lotes` | `sp_Lotes_ListarPorProducto` |
| 7 | Movimientos | `features/movimientos/movimientos.ts` | `/api/movimientos` | `sp_Movimientos_RegistrarEntrada/Salida` |
| 8 | Alertas | `features/alertas/alertas.ts` | `/api/alertas` | `sp_Alertas_StockBajo/PorVencer` |
| 9 | Reportes/Kardex | `features/reportes/reportes.ts` | `/api/reportes` + `/api/movimientos` | `sp_Reportes_*` + `sp_Movimientos_Listar` |
| 10 | Usuarios y Roles | `features/usuarios/usuarios.ts`, `features/roles/roles.ts` | `/api/usuarios`, `/api/roles`, `/api/permisos` | `sp_Usuarios_*`, `sp_Roles_*`, `sp_Permisos_*` |

**Dato clave:** no existe un servicio Angular por módulo. Todos los componentes inyectan `ApiService` (`api.service.ts`); solo autenticación pasa primero por `AuthService`.

---

## 4. Fichas por módulo

---

### Ficha 1 — Autenticación (Login)

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/auth/login/login.ts` |
| Template | `frontend/src/app/features/auth/login/login.html` |
| Estilos | `frontend/src/app/features/auth/login/login.scss` |

#### Variables `signal()` y formulario

| Línea | Elemento | Tipo |
|---|---|---|
| `login.ts:40` | `loginModel` | `signal<DatosLogin>({ email:'', password:'' })` |
| `login.ts:45` | `loginForm` | `form(this.loginModel, ...)` (Signal Forms de Angular 21) |
| `login.ts:54` | `email` | `computed(() => loginModel().email)` |
| `login.ts:55` | `password` | `computed(() => loginModel().password)` |
| `login.ts:57` | `cargando` | `signal(false)` |
| `login.ts:58` | `error` | `signal<string \| null>(null)` |
| `login.ts:59` | `mostrarPassword` | `signal(false)` |

Métodos principales:

| Línea | Método | Función |
|---|---|---|
| `login.ts:64-90` | `enviar(evento)` | valida con `submit(loginForm)` y llama `auth.login()` |
| `login.ts:92` | `alternarPassword()` | muestra/oculta contraseña |
| `login.ts:96` | `obtenerReturnUrl()` | lee `?returnUrl=` y evita open redirect |
| `login.ts:107` | `mensajeError()` | normaliza el error de la API |

Template: `login.html:72` → `<form (submit)="enviar($event)" novalidate>`.

#### Servicio Angular

| Línea | Método | Detalle |
|---|---|---|
| `core/services/auth.service.ts:80` | `login(email, password)` | delega en `ApiService.login` (`:84`) y guarda la sesión |
| `core/services/api.service.ts:243-257` | `login(email, password)` | `POST /api/auth/login` con `application/x-www-form-urlencoded` (`username`, `password`) y luego hidrata con `/auth/me` |

#### Endpoint FastAPI

| Archivo | Línea | Función |
|---|---|---|
| `backend/src/backend/apis/auth_api.py` | 12 | `router = APIRouter(prefix="/api/auth")` |
| `backend/src/backend/apis/auth_api.py` | 15-16 | `@router.post("/login")` → `def login(datos: OAuth2PasswordRequestForm)` |
| `backend/src/backend/apis/auth_api.py` | 24-25 | `@router.get("/me")` → `def me(...)` |

#### Service y Repository

| Capa | Archivo:línea | Función |
|---|---|---|
| Service | `backend/src/backend/services/auth_service.py:30` | `autenticar(email, password)` |
| Service | `backend/src/backend/services/auth_service.py:43` | `obtener_usuario_por_email()` |
| Repository | `backend/src/backend/repositories/usuario_repository.py:46` | `obtener_sesion(email)` |
| Seguridad | `backend/src/backend/security.py` | verificación Argon2id del hash |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Usuarios_ObtenerSesion` | `database/03_sp_usuarios.sql:12` |

> **Importante:** no existe `sp_Usuarios_Login`. El SP solo devuelve usuario + roles + permisos (tres result sets) y **el hash se verifica en Python** con Argon2id. `password_hash` nunca sale en la respuesta.

#### Simulacro de examen

**Pregunta 1:** “Cuando el usuario pulsa *Ingresar*, ¿dónde se llama exactamente a la API?”

**Respuesta:** en `login.ts:77` (`this.auth.login(...)`), que llega a `core/services/auth.service.ts:80`; este llama `api.service.ts:243-257`, donde se hace el `POST` a `${base}/auth/login` con `Content-Type: application/x-www-form-urlencoded` (`username` = correo, `password`). El endpoint que lo recibe es `apis/auth_api.py:16` (`login`).

**Pregunta 2:** “¿Qué Stored Procedure valida el usuario y dónde se comprueba la contraseña?”

**Respuesta:** el SP es `dbo.sp_Usuarios_ObtenerSesion`, definido en `database/03_sp_usuarios.sql:12` y ejecutado desde `repositories/usuario_repository.py:46` (`obtener_sesion`). La contraseña **no** se valida en SQL: el hash viaja al service y se verifica con Argon2id en `backend/src/backend/security.py` dentro de `auth_service.autenticar` (`services/auth_service.py:30`).

---

### Ficha 2 — Dashboard

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/dashboard/dashboard.ts` |
| Template | `frontend/src/app/features/dashboard/dashboard.html` |
| Estilos | `frontend/src/app/features/dashboard/dashboard.scss` |

#### Estado y métodos

| Línea | Elemento | Detalle |
|---|---|---|
| `dashboard.ts:30` | `resumen` | `this.api.resumen` (`Recurso<ResumenInventario>`) |
| `dashboard.ts:31` | `stockBajo` | `this.api.stockBajo` |
| `dashboard.ts:32` | `porVencer` | `this.api.porVencer` |
| `dashboard.ts:33` | `vencidos` | `this.api.vencidos` |
| `dashboard.ts:50-81` | métricas | `computed()`: `totalProductos`, `valorInventario`, `movimientosPeriodo`, `totalAlertas`, `lotesEnRiesgo`, `topStockBajo`, `topPorVencer`, `accesos` |
| `dashboard.ts:83-95` | `ngOnInit()` | valida `dashboard:leer` y dispara `cargarResumen()`, `cargarStockBajo()`, `cargarPorVencer(30)`, `cargarVencidos()` |

> El dashboard **no tiene formulario**: solo lectura y navegación. Su estado son los `Recurso` de `ApiService` y `computed()`.

#### Servicio Angular

| Línea | Método |
|---|---|
| `api.service.ts:683` | `cargarResumen(desde?, hasta?)` → `GET /api/dashboard/resumen` |
| `api.service.ts:658` | `cargarStockBajo()` |
| `api.service.ts:665` | `cargarPorVencer(dias = 30)` |
| `api.service.ts:675` | `cargarVencidos()` |

#### Endpoint FastAPI

| Archivo:línea | Función |
|---|---|
| `backend/src/backend/apis/dashboard_api.py:13` | `APIRouter(prefix="/api/dashboard")` |
| `backend/src/backend/apis/dashboard_api.py:18-19` | `@router.get("/resumen")` → `def resumen(...)` |

#### Service y Repository

| Capa | Archivo:línea | Función |
|---|---|---|
| Service | `services/alerta_service.py:42` | `obtener_resumen(desde, hasta)` |
| Repository | `repositories/alerta_repository.py:38` | `obtener_resumen(desde, hasta)` |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Dashboard_Resumen` | `database/10_sp_alertas_dashboard.sql:76` |
| `dbo.sp_Alertas_StockBajo` | `database/10_sp_alertas_dashboard.sql:15` |
| `dbo.sp_Alertas_PorVencer` | `database/10_sp_alertas_dashboard.sql:48` |

#### Simulacro de examen

**Pregunta 1:** “¿Qué archivo pinta las tarjetas del dashboard y de dónde salen los números?”

**Respuesta:** el template es `features/dashboard/dashboard.html` y la lógica `dashboard.ts`. Los números salen de los signals `resumen`, `stockBajo`, `porVencer` y `vencidos` (`dashboard.ts:30-33`), alimentados en `dashboard.ts:88-93` por `ApiService.cargarResumen()` (`api.service.ts:683`), que llama `GET /api/dashboard/resumen`.

**Pregunta 2:** “¿Qué SP calcula el resumen y dónde está definido?”

**Respuesta:** `dbo.sp_Dashboard_Resumen`, en `database/10_sp_alertas_dashboard.sql:76`. El flujo es `dashboard_api.py:19` → `services/alerta_service.py:42` → `repositories/alerta_repository.py:38` → `EXEC dbo.sp_Dashboard_Resumen`.

---

### Ficha 3 — Categorías

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/categorias/categorias.ts` |
| Template | `frontend/src/app/features/categorias/categorias.html` |
| Estilos | `frontend/src/app/features/categorias/categorias.scss` |

#### Variables `signal()` y formulario

| Línea | Elemento |
|---|---|
| `categorias.ts:49` | `filtroBusqueda = signal('')` |
| `categorias.ts:50` | `filtroEstado = signal<FiltroEstado>('todos')` |
| `categorias.ts:58` | `modalAbierto = signal(false)` |
| `categorias.ts:59` | `categoriaEditando = signal<Categoria \| null>(null)` |
| `categorias.ts:60` | `guardando = signal(false)` |
| `categorias.ts:61` | `reactivandoId = signal<number \| null>(null)` |
| `categorias.ts:62` | `errorModal = signal<string \| null>(null)` |
| `categorias.ts:63` | `intentado = signal(false)` |
| `categorias.ts:67` | `nombre = signal('')` |
| `categorias.ts:68` | `descripcion = signal('')` |

Métodos principales:

| Línea | Método |
|---|---|
| `categorias.ts:127` | `ngOnInit()` |
| `categorias.ts:133` | `recargarCategorias()` |
| `categorias.ts:139/143/148` | `cambiarFiltroBusqueda/Estado`, `limpiarFiltros` |
| `categorias.ts:155/162/169` | `abrirCrear`, `abrirEditar`, `cerrarModal` |
| `categorias.ts:178/182` | `cambiarNombre`, `cambiarDescripcion` |
| `categorias.ts:186` | `guardar(evento)` |
| `categorias.ts:263` | `reactivar(categoria)` |

Template: tabla en `categorias.html:110`; modal en `:213`; formulario en `:214` → `(submit)="guardar($event)"`.

#### Servicio Angular (`api.service.ts`)

| Línea | Método |
|---|---|
| 480 | `cargarCategorias(soloActivos?)` |
| 489 | `obtenerCategoria(id)` |
| 495 | `crearCategoria(datos)` |
| 501 | `actualizarCategoria(id, datos)` |
| 514 | `desactivarCategoria(id)` |

#### Endpoint FastAPI

Archivo: `backend/src/backend/apis/categoria_api.py` (router en `:18`, prefijo `/api/categorias`)

| Línea | Función |
|---|---|
| 24-25 | `@router.get("")` → `listar()` |
| 30-31 | `@router.get("/{id_categoria}")` → `obtener()` |
| 36-37 | `@router.post("")` → `crear()` |
| 45-46 | `@router.put("/{id_categoria}")` → `actualizar()` |
| 61-62 | `@router.delete("/{id_categoria}")` → `desactivar()` |

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service | `services/categoria_service.py:15,29,45,63` |
| Repository | `repositories/categoria_repository.py:35,45,58,79` |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Categorias_Listar` | `database/05_sp_categorias.sql:11` |
| `dbo.sp_Categorias_Obtener` | `database/05_sp_categorias.sql:24` |
| `dbo.sp_Categorias_Crear` | `database/05_sp_categorias.sql:36` |
| `dbo.sp_Categorias_Actualizar` | `database/05_sp_categorias.sql:53` |
| `dbo.sp_Categorias_Desactivar` | `database/05_sp_categorias.sql:90` |

#### Simulacro de examen

**Pregunta 1:** “¿Dónde está el formulario de alta/edición de categorías y qué método lo envía?”

**Respuesta:** el formulario está en `features/categorias/categorias.html:214` (`<form id="form-categoria" (submit)="guardar($event)">`), dentro del modal de `:213`. El método es `categorias.ts:186` (`guardar`), que usa `ApiService.crearCategoria` (`api.service.ts:495`) o `actualizarCategoria` (`:501`) según `categoriaEditando()`.

**Pregunta 2:** “¿Qué SP impide borrar una categoría con productos activos?”

**Respuesta:** `dbo.sp_Categorias_Desactivar`, en `database/05_sp_categorias.sql:90`. Lanza el código `51404`, que `repositories/categoria_repository.py` traduce a conflicto y `main.py` responde **409**. El detalle de la regla está en `errores_sql.py` (`clasificar`).

---

### Ficha 4 — Áreas Hospitalarias

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/areas/areas.ts` |
| Template | `frontend/src/app/features/areas/areas.html` |
| Estilos | `frontend/src/app/features/areas/areas.scss` |

#### Variables `signal()` y formulario

| Línea | Elemento |
|---|---|
| `areas.ts:48` | `busqueda = signal('')` |
| `areas.ts:49` | `filtroEstado = signal<FiltroEstado>('todos')` |
| `areas.ts:71` | `modalAbierto = signal(false)` |
| `areas.ts:72` | `editando = signal<Area \| null>(null)` |
| `areas.ts:73` | `nombre = signal('')` |
| `areas.ts:74` | `nombreTocado = signal(false)` |
| `areas.ts:75` | `guardando = signal(false)` |
| `areas.ts:76` | `procesando = signal<number \| null>(null)` |

Métodos principales:

| Línea | Método |
|---|---|
| `areas.ts:99` | `ngOnInit()` |
| `areas.ts:106` | `recargar()` |
| `areas.ts:123/133/143` | `abrirAlta`, `abrirEdicion`, `cerrarModal` |
| `areas.ts:150/155` | `actualizarNombre`, `marcarNombreTocado` |
| `areas.ts:159` | `guardar()` |
| `areas.ts:183` | `desactivar(area)` |
| `areas.ts:211` | `reactivar(area)` |

Template: tabla en `areas.html:71`; modal en `:176`; formulario en `:182` → `(submit)="$event.preventDefault(); guardar()"`.

#### Servicio Angular

| Línea | Método |
|---|---|
| `api.service.ts:443` | `cargarAreas(soloActivos?)` |
| `api.service.ts:452` | `obtenerArea(id)` |
| `api.service.ts:456` | `crearArea(datos)` |
| `api.service.ts:462` | `actualizarArea(id, datos)` |
| `api.service.ts:472` | `desactivarArea(id)` |

El mismo `cargarAreas` alimenta el selector de área del formulario de salidas (`movimientos.ts:637`).

#### Endpoint FastAPI

Archivo: `backend/src/backend/apis/area_api.py` (router en `:18`, prefijo `/api/areas`)

| Línea | Función |
|---|---|
| 24-25 | `listar(solo_activos?)` |
| 32-33 | `obtener(id_area)` |
| 38-39 | `crear(datos)` |
| 47-48 | `actualizar(id_area, datos)` |
| 57-58 | `desactivar(id_area)` |

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service | `services/area_service.py:15,29,38,49` |
| Repository | `repositories/area_repository.py:37,47,55,66` |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Areas_Listar` | `database/09_sp_areas.sql:12` |
| `dbo.sp_Areas_Obtener` | `database/09_sp_areas.sql:25` |
| `dbo.sp_Areas_Crear` | `database/09_sp_areas.sql:37` |
| `dbo.sp_Areas_Actualizar` | `database/09_sp_areas.sql:53` |
| `dbo.sp_Areas_Desactivar` | `database/09_sp_areas.sql:81` |

> `sp_Areas_Desactivar` rechaza el área con movimientos mediante `THROW 51504` → HTTP **409**. Así se conserva la trazabilidad de los consumos.

#### Simulacro de examen

**Pregunta 1:** “¿En qué archivo está el CRUD de áreas y cuál es su endpoint?”

**Respuesta:** componente `features/areas/areas.ts` + template `areas.html`; servicio `api.service.ts:443-472`; router `apis/area_api.py` (`:18` prefijo `/api/areas`, funciones en `:25`, `:33`, `:39`, `:48`, `:58`).

**Pregunta 2:** “¿Qué pasa si intento desactivar un área que ya tiene salidas registradas y dónde se controla?”

**Respuesta:** se bloquea en `dbo.sp_Areas_Desactivar` (`database/09_sp_areas.sql:81`) con `THROW 51504`. El repository `repositories/area_repository.py:66` lo traduce a `ConflictoEstado` y `main.py` devuelve **409**; el frontend lo muestra con `areas.ts:183` (`desactivar`).

---

### Ficha 5 — Productos

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/productos/productos.ts` |
| Template | `frontend/src/app/features/productos/productos.html` |
| Estilos | `frontend/src/app/features/productos/productos.scss` |

#### Variables `signal()` y formulario

| Línea | Elemento |
|---|---|
| `productos.ts:64` | `filtroBusqueda = signal('')` |
| `productos.ts:65` | `filtroCategoria = signal<number \| null>(null)` |
| `productos.ts:66` | `filtroEstado = signal<FiltroEstado>('todos')` |
| `productos.ts:68` | `pagina = signal(1)` |
| `productos.ts:94` | `modalAbierto = signal(false)` |
| `productos.ts:95` | `productoEditando = signal<ProductoListado \| null>(null)` |
| `productos.ts:96` | `guardando = signal(false)` |
| `productos.ts:97` | `errorModal = signal<string \| null>(null)` |
| `productos.ts:98` | `intentado = signal(false)` |
| `productos.ts:102-110` | `codigo`, `nombre`, `descripcion`, `idCategoria`, `unidadMedida`, `precioUnitario`, `stockMinimo`, `manejaLotes`, `requiereVencimiento` |

Métodos principales:

| Línea | Método |
|---|---|
| `productos.ts:227` | `ngOnInit()` |
| `productos.ts:234/240` | `recargarProductos`, `recargarCategorias` |
| `productos.ts:246-265` | filtros y `limpiarFiltros` |
| `productos.ts:272` | `irPagina(pagina)` |
| `productos.ts:279/286/293` | `abrirCrear`, `abrirEditar`, `cerrarModal` |
| `productos.ts:302/326/331` | `cambiarTexto`, `cambiarCategoria`, `cambiarBooleano` |
| `productos.ts:353` | `guardar(evento)` |
| `productos.ts:413` | `desactivar(producto)` |
| `productos.ts:486/497` | `filtrosServidor`, `prepararFormulario` |

Template: tabla en `productos.html:139`; modal en `:261`; formulario en `:262` → `(submit)="guardar($event)"`.

#### Servicio Angular

| Línea | Método |
|---|---|
| `api.service.ts:526` | `cargarProductos(filtros?)` |
| `api.service.ts:538` | `cargarProductosPagina(...)` |
| `api.service.ts:551` | `obtenerProducto(id)` |
| `api.service.ts:557` | `crearProducto(datos)` |
| `api.service.ts:563` | `actualizarProducto(id, datos)` |
| `api.service.ts:585` | `desactivarProducto(id)` |

#### Endpoint FastAPI

Archivo: `backend/src/backend/apis/producto_api.py` (router en `:23`, prefijo `/api/productos`)

| Línea | Función |
|---|---|
| 29-30 | `listar(busqueda?, id_categoria?, solo_activos?, pagina?, tamano?)` |
| 50-51 | `obtener(id_producto)` |
| 56-57 | `crear(datos)` |
| 65-66 | `actualizar(id_producto, datos)` |
| 75-76 | `desactivar(id_producto)` |

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service | `services/producto_service.py:21,43,64,90` |
| Repository | `repositories/producto_repository.py:40,65,98,132` |
| Schema | `schemas/producto.py` (`ProductoCrear`, `ProductoActualizar` con `extra="forbid"`) |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Productos_Listar` | `database/06_sp_productos.sql:12` |
| `dbo.sp_Productos_Obtener` | `database/06_sp_productos.sql:75` |
| `dbo.sp_Productos_Crear` | `database/06_sp_productos.sql:97` |
| `dbo.sp_Productos_Actualizar` | `database/06_sp_productos.sql:148` |
| `dbo.sp_Productos_Desactivar` | `database/06_sp_productos.sql:196` |

> **Dos schemas distintos:** `Producto` (11 columnas, `sp_Productos_Obtener`) y `ProductoListado` (14 columnas, añade `categoria`, `stock_total`, `stock_disponible`). No se deben unificar.

#### Simulacro de examen

**Pregunta 1:** “¿Dónde está la llamada que trae el listado paginado de productos?”

**Respuesta:** `productos.ts:234` (`recargarProductos`) llama `ApiService.cargarProductosPagina` (`api.service.ts:538`), que hace `GET /api/productos` con `pagina`/`tamano` y lee `X-Total-Count`. El endpoint es `producto_api.py:30` (`listar`), que llega a `sp_Productos_Listar` (`database/06_sp_productos.sql:12`).

**Pregunta 2:** “¿Por qué no se puede cambiar el stock desde el formulario de productos?”

**Respuesta:** porque `ProductoActualizar` (`backend/src/backend/schemas/producto.py`) no expone `stock` y usa `extra="forbid"`: un campo extra responde **422**. Además el SP `sp_Productos_Actualizar` (`database/06_sp_productos.sql:148`) no recibe stock; el stock solo cambia con entradas/salidas (`08_sp_movimientos.sql`).

---

### Ficha 6 — Lotes

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/lotes/lotes.ts` |
| Template | `frontend/src/app/features/lotes/lotes.html` |
| Estilos | `frontend/src/app/features/lotes/lotes.scss` |

#### Variables `signal()` y métodos

| Línea | Elemento |
|---|---|
| `lotes.ts:38` | `idProducto = signal<number \| null>(null)` |
| `lotes.ts:39` | `lotes = signal<Lote[]>([])` |
| `lotes.ts:40` | `cargandoLotes = signal(false)` |
| `lotes.ts:41` | `errorLotes = signal<string \| null>(null)` |
| `lotes.ts:42` | `errorProductos = signal<string \| null>(null)` |
| `lotes.ts:64` | `ngOnInit()` |
| `lotes.ts:71` | `seleccionarProducto(evento)` |
| `lotes.ts:82/86` | `reintentarProductos`, `reintentarLotes` |
| `lotes.ts:93` | `cargarProductos()` |
| `lotes.ts:106` | `cargarLotes(idProducto)` |

Template: tabla de lotes en `lotes.html:179`. La pantalla es **solo lectura**: no hay CRUD de lotes.

#### Servicio Angular

| Línea | Método |
|---|---|
| `api.service.ts:597` | `cargarLotes(idProducto)` → `GET /api/productos/{id}/lotes` |

#### Endpoint FastAPI

| Archivo:línea | Función |
|---|---|
| `apis/lote_api.py:9` | `APIRouter(prefix="/api/productos")` |
| `apis/lote_api.py:14-15` | `@router.get("/{id_producto}/lotes")` → `def listar(id_producto)` |

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service | `services/lote_service.py:10` |
| Repository | `repositories/lote_repository.py:7` (`listar_lotes_por_producto`), `:14` (`obtener_lote`) |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Lotes_ListarPorProducto` | `database/07_sp_lotes.sql:12` |
| `dbo.sp_Lotes_Obtener` | `database/07_sp_lotes.sql:34` |

> Los lotes **no se crean desde esta pantalla**: se generan al registrar una entrada (`sp_Movimientos_RegistrarEntrada`, `database/08_sp_movimientos.sql:13`). El campo `vencido` del SP usa `fecha_vencimiento <= hoy`.

#### Simulacro de examen

**Pregunta 1:** “¿En qué archivo se consultan los lotes de un producto y a qué endpoint va?”

**Respuesta:** `features/lotes/lotes.ts:106` (`cargarLotes`) → `api.service.ts:597` → `GET /api/productos/{id}/lotes` → `apis/lote_api.py:15` (`listar`) → `services/lote_service.py:10` → `repositories/lote_repository.py:7` → `EXEC dbo.sp_Lotes_ListarPorProducto` (`database/07_sp_lotes.sql:12`).

**Pregunta 2:** “¿Por qué no hay un formulario para crear lotes?”

**Respuesta:** porque el diseño lo prohíbe: el stock solo se mueve con entradas y salidas. El lote nace dentro de `sp_Movimientos_RegistrarEntrada` (`database/08_sp_movimientos.sql:13`) cuando el producto maneja lotes; `repositories/lote_repository.py` solo tiene lectura.

---

### Ficha 7 — Movimientos (Entradas y Salidas)

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/movimientos/movimientos.ts` |
| Template | `frontend/src/app/features/movimientos/movimientos.html` |
| Estilos | `frontend/src/app/features/movimientos/movimientos.scss` |

#### Variables `signal()` del historial

| Línea | Elemento |
|---|---|
| `movimientos.ts:77` | `motivosEntrada = signal(MOTIVOS_ENTRADA)` |
| `movimientos.ts:83` | `busqueda = signal('')` |
| `movimientos.ts:84` | `tipoFiltro = signal<FiltroTipo>('TODOS')` |
| `movimientos.ts:85` | `idAreaFiltro = signal<number \| null>(null)` |
| `movimientos.ts:86/87` | `desde`, `hasta` |
| `movimientos.ts:89` | `pagina = signal(1)` |

#### Signals del formulario de ENTRADA

| Línea | Elemento |
|---|---|
| `movimientos.ts:128` | `modalEntrada = signal(false)` |
| `movimientos.ts:130` | `guardando = signal(false)` |
| `movimientos.ts:134` | `idProductoEntrada = signal<number \| null>(null)` |
| `movimientos.ts:135` | `cantidadEntrada = signal('')` |
| `movimientos.ts:136` | `motivoEntrada = signal<MotivoEntrada \| ''>('')` |
| `movimientos.ts:137` | `numeroLoteEntrada = signal('')` |
| `movimientos.ts:138` | `fechaVencimientoEntrada = signal('')` |
| `movimientos.ts:139` | `intentoEntrada = signal(false)` |

Métodos de entrada: `abrirEntrada` `:324`, `cambiarProductoEntrada` `:339`, `actualizarCantidadEntrada` `:345`, `actualizarMotivoEntrada` `:349`, `actualizarNumeroLoteEntrada` `:360`, `actualizarFechaVencimientoEntrada` `:364`, **`enviarEntrada` `:368`**.

#### Signals del formulario de SALIDA

| Línea | Elemento |
|---|---|
| `movimientos.ts:129` | `modalSalida = signal(false)` |
| `movimientos.ts:192` | `idProductoSalida = signal<number \| null>(null)` |
| `movimientos.ts:193` | `idLoteSalida = signal<number \| null>(null)` |
| `movimientos.ts:194` | `idAreaSalida = signal<number \| null>(null)` |
| `movimientos.ts:195` | `cantidadSalida = signal('')` |
| `movimientos.ts:196` | `motivoSalida = signal('')` |
| `movimientos.ts:197` | `intentoSalida = signal(false)` |
| `movimientos.ts:199` | `lotesSalida = signal<Lote[]>([])` |
| `movimientos.ts:200` | `cargandoLotesSalida = signal(false)` |
| `movimientos.ts:201` | `errorLotesSalida = signal<string \| null>(null)` |

Métodos de salida: `abrirSalida` `:417`, `cambiarProductoSalida` `:432`, `cambiarLoteSalida` `:448`, `cambiarAreaSalida` `:452`, `actualizarCantidadSalida` `:456`, `actualizarMotivoSalida` `:460`, **`enviarSalida` `:464`**, `cargarLotesSalida` `:556`, `filtrosServidor` `:614`.

#### Template

| Elemento | Línea |
|---|---|
| Formulario de filtros | `movimientos.html:39` |
| Tabla historial | `movimientos.html:179` |
| Modal de entrada | `movimientos.html:260` / form `:266` |
| Modal de salida | `movimientos.html:449` / form `:455` |
| Selector de lote con **“Automático (FEFO)”** | `movimientos.html:493-505` |

#### Servicio Angular

| Línea | Método | Endpoint |
|---|---|---|
| `api.service.ts:612` | `cargarMovimientos(filtros?)` | `GET /api/movimientos` |
| `api.service.ts:629` | `consultarMovimientos(filtros)` | `GET /api/movimientos` (usado por Kardex) |
| `api.service.ts:638` | `cargarMotivosEntrada()` | `GET /api/movimientos/motivos-entrada` |
| `api.service.ts:644` | `registrarEntrada(datos)` | `POST /api/movimientos/entradas` |
| `api.service.ts:650` | `registrarSalida(datos)` | `POST /api/movimientos/salidas` |

#### Endpoint FastAPI

Archivo: `backend/src/backend/apis/movimiento_api.py` (router en `:24`, prefijo `/api/movimientos`)

| Línea | Función |
|---|---|
| 31-36 | `@router.get("/motivos-entrada")` → `motivos_entrada()` |
| 41-42 | `@router.get("")` → `listar(...)` |
| 72-75 | `@router.post("/entradas")` → `crear_entrada(datos)` |
| 83-86 | `@router.post("/salidas")` → `crear_salida(datos)` |

#### Service y Repository

| Capa | Archivo:línea | Función |
|---|---|---|
| Service | `services/movimiento_service.py:20` | `listar_movimientos(...)` |
| Service | `services/movimiento_service.py:37` | `registrar_entrada(datos, id_usuario)` |
| Service | `services/movimiento_service.py:54` | `registrar_salida(datos, id_usuario)` |
| Repository | `repositories/movimiento_repository.py:49` | `registrar_entrada(...)` |
| Repository | `repositories/movimiento_repository.py:75` | `registrar_salida(...)` |
| Repository | `repositories/movimiento_repository.py:104` | `listar_movimientos(...)` |
| Repository | `repositories/movimiento_repository.py:130` | `obtener_movimiento(id)` |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Movimientos_RegistrarEntrada` | `database/08_sp_movimientos.sql:13` |
| `dbo.sp_Movimientos_RegistrarSalida` | `database/08_sp_movimientos.sql:152` |
| `dbo.sp_Movimientos_Listar` | `database/08_sp_movimientos.sql:307` |
| `dbo.sp_Movimientos_Obtener` | `database/08_sp_movimientos.sql:371` |

**Reglas dentro de los SP:**
- `id_usuario` sale del token, nunca del body (`EntradaCrear`/`SalidaCrear` usan `extra="forbid"`).
- Transacción de stock en SQL: `BEGIN TRAN` + `XACT_ABORT` + `ROLLBACK` en el `CATCH`.
- **FEFO:** `@id_lote` es opcional; si llega `NULL`, el SP elige el lote vigente con vencimiento más próximo (`08_sp_movimientos.sql:196-220`).
- Vencido: `fecha_vencimiento <= hoy` bloquea con `51208`.
- Stock insuficiente: `51209` → 409.
- La auditoría se inserta **dentro de la misma transacción** del movimiento.

#### Simulacro de examen

**Pregunta 1:** “¿Dónde está el formulario de salidas y qué método lo procesa?”

**Respuesta:** en `features/movimientos/movimientos.html:455` (`<form (submit)="enviarSalida($event)">`), dentro del modal de `:449`. El método es `movimientos.ts:464` (`enviarSalida`), que arma el objeto y llama `ApiService.registrarSalida` (`api.service.ts:650`) → `POST /api/movimientos/salidas` (`movimiento_api.py:86`) → `services/movimiento_service.py:54` → `repositories/movimiento_repository.py:75` → `dbo.sp_Movimientos_RegistrarSalida` (`database/08_sp_movimientos.sql:152`).

**Pregunta 2:** “Si no elijo lote, ¿quién aplica FEFO y dónde está ese código?”

**Respuesta:** lo aplica el servidor, no el frontend. En `database/08_sp_movimientos.sql:196-220` el SP, cuando `@id_lote IS NULL`, hace `SELECT TOP (1)` del lote con `stock_actual >= @cantidad` y `fecha_vencimiento > hoy`, ordenado por vencimiento más próximo. El frontend solo envía `id_lote: null` (`movimientos.ts:487`) y muestra la opción “Automático (FEFO)” (`movimientos.html:501`).

---

### Ficha 8 — Alertas

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/alertas/alertas.ts` |
| Template | `frontend/src/app/features/alertas/alertas.html` |
| Estilos | `frontend/src/app/features/alertas/alertas.scss` |

#### Variables `signal()` y métodos

| Línea | Elemento |
|---|---|
| `alertas.ts:48` | `pestana = signal<PestanaAlertas>('stock-bajo')` |
| `alertas.ts:49` | `busqueda = signal('')` |
| `alertas.ts:50` | `dias = signal(30)` |
| `alertas.ts:111` | `ngOnInit()` |
| `alertas.ts:121` | `seleccionarPestana(pestana)` |
| `alertas.ts:125/129` | `actualizarBusqueda`, `actualizarDias` |
| `alertas.ts:134/140/146` | `recargarStockBajo`, `recargarVencidos`, `recargarPorVencer` |
| `alertas.ts:152` | `actualizarPorVencer()` |

Template: una tabla por pestaña → stock bajo `alertas.html:203`, por vencer `:282`, vencidos `:355`.

#### Servicio Angular

| Línea | Método | Endpoint |
|---|---|---|
| `api.service.ts:658` | `cargarStockBajo()` | `GET /api/alertas/stock-bajo` |
| `api.service.ts:665` | `cargarPorVencer(dias = 30)` | `GET /api/alertas/por-vencer` |
| `api.service.ts:675` | `cargarVencidos()` | `GET /api/alertas/vencidos` |

#### Endpoint FastAPI

Archivo: `backend/src/backend/apis/alerta_api.py` (router en `:17`, prefijo `/api/alertas`)

| Línea | Función |
|---|---|
| 22-25 | `@router.get("/stock-bajo")` → `stock_bajo()` |
| 30-31 | `@router.get("/por-vencer")` → `por_vencer(dias)` |
| 38-39 | `@router.get("/vencidos")` → `vencidos()` |
| 44-45 | `@router.get("/resumen")` → `resumen(desde?, hasta?)` |

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service | `services/alerta_service.py:13,19,31,42` |
| Repository | `repositories/alerta_repository.py:20,25,38` |

#### Stored Procedure

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Alertas_StockBajo` | `database/10_sp_alertas_dashboard.sql:15` |
| `dbo.sp_Alertas_PorVencer` | `database/10_sp_alertas_dashboard.sql:48` |
| `dbo.sp_Dashboard_Resumen` | `database/10_sp_alertas_dashboard.sql:76` |

**Regla de negocio:** `VENCIDO` = `fecha_vencimiento <= hoy`; `PROXIMO` = 1 a 30 días. Por eso “por vencer” con 30 días no incluye el día actual.

#### Simulacro de examen

**Pregunta 1:** “¿Dónde se cargan las tres pestañas de alertas?”

**Respuesta:** en `features/alertas/alertas.ts:134-152` (`recargarStockBajo`, `recargarVencidos`, `recargarPorVencer`), usando `ApiService` en `api.service.ts:658`, `:675` y `:665`. El backend está en `apis/alerta_api.py:25` (`stock_bajo`), `:39` (`vencidos`) y `:31` (`por_vencer`).

**Pregunta 2:** “¿Qué SP decide si un lote está vencido y con qué comparación?”

**Respuesta:** `dbo.sp_Alertas_PorVencer`, en `database/10_sp_alertas_dashboard.sql:48`. Calcula `estado = 'VENCIDO'` cuando `fecha_vencimiento <= CONVERT(date, GETDATE())`; el resto dentro de la ventana es `'PROXIMO'`. El service filtra los `PROXIMO` en `services/alerta_service.py:19` y los `VENCIDO` en `:31`.

---

### Ficha 9 — Reportes / Kardex

#### Ubicación del componente

| Capa | Archivo |
|---|---|
| Componente | `frontend/src/app/features/reportes/reportes.ts` |
| Template | `frontend/src/app/features/reportes/reportes.html` |
| Estilos | `frontend/src/app/features/reportes/reportes.scss` |

#### Variables `signal()` y métodos

| Línea | Elemento |
|---|---|
| `reportes.ts:62` | `pestana = signal<PestanaReportes>('kardex')` |
| `reportes.ts:68` | `idProducto = signal<number \| null>(null)` |
| `reportes.ts:69/70` | `desdeKardex`, `hastaKardex` |
| `reportes.ts:71` | `kardex = signal<MovimientoListado[]>([])` |
| `reportes.ts:72-76` | `cargandoKardex`, `errorKardex`, `consultadoKardex`, `intentoKardex`, `filtroKardex` |
| `reportes.ts:80-86` | `desdeMayores`, `hastaMayores`, `top`, `mayores`, `cargandoMayores`, `errorMayores`, `intentoMayores` |

Métodos principales:

| Línea | Método |
|---|---|
| `reportes.ts:157` | `ngOnInit()` |
| `reportes.ts:166` | `seleccionarPestana()` |
| `reportes.ts:172` | `recargarProductos()` |
| `reportes.ts:178-196` | actualizadores de filtros del kardex |
| `reportes.ts:200-239` | **`consultarKardex()`** |
| `reportes.ts:243-258` | filtros y `consultarMayores()` |
| `reportes.ts:270-303` | `ejecutarMayores(notificar)` |

Template: tabla del kardex en `reportes.html:226`; tabla de mayores salidas en `:375`.

#### Servicio Angular

| Línea | Método | Endpoint |
|---|---|---|
| `api.service.ts:629` | `consultarMovimientos(filtros)` | `GET /api/movimientos` ← **kardex** |
| `api.service.ts:706` | `cargarMayoresSalidas(filtros)` | `GET /api/reportes/mayores-salidas` |
| `api.service.ts:715` | `cargarConsumoPorArea(rango)` | `GET /api/reportes/consumo-por-area` |
| `api.service.ts:724` | `cargarStockValorizado()` | `GET /api/reportes/stock-valorizado` |

> **Dato clave:** el **kardex no tiene endpoint propio**. `reportes.ts:216` llama `consultarMovimientos`, que pega en `GET /api/movimientos` con `id_producto`, `desde` y `hasta`.

#### Endpoint FastAPI

**Kardex** → `backend/src/backend/apis/movimiento_api.py:41-42` (`listar`).

**Reportes agregados** → `backend/src/backend/apis/reporte_api.py` (router en `:17`, prefijo `/api/reportes`)

| Línea | Función |
|---|---|
| 22-23 | `@router.get("/mayores-salidas")` → `mayores(...)` |
| 33-34 | `@router.get("/consumo-por-area")` → `consumo(...)` |
| 43-44 | `@router.get("/stock-valorizado")` → `stock()` |

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service (kardex) | `services/movimiento_service.py:20` |
| Repository (kardex) | `repositories/movimiento_repository.py:104` |
| Service (reportes) | `services/reporte_service.py:13,21,27` |
| Repository (reportes) | `repositories/reporte_repository.py:20,31,41` |

#### Stored Procedure

| Uso | SP | Archivo:línea |
|---|---|---|
| Kardex | `dbo.sp_Movimientos_Listar` | `database/08_sp_movimientos.sql:307` |
| Mayores salidas | `dbo.sp_Reportes_MayoresSalidas` | `database/11_sp_reportes.sql:11` |
| Consumo por área | `dbo.sp_Reportes_ConsumoPorArea` | `database/11_sp_reportes.sql:40` |
| Stock valorizado | `dbo.sp_Reportes_StockValorizado` | `database/11_sp_reportes.sql:64` |

#### Simulacro de examen

**Pregunta 1:** “¿Dónde se consulta el kardex y cuál es su endpoint?”

**Respuesta:** en `features/reportes/reportes.ts:200-239` (`consultarKardex`), que llama `ApiService.consultarMovimientos` (`api.service.ts:629`) → `GET /api/movimientos` (`movimiento_api.py:42`) → `movimiento_service.listar_movimientos` (`services/movimiento_service.py:20`) → `repositories/movimiento_repository.py:104` → `dbo.sp_Movimientos_Listar` (`database/08_sp_movimientos.sql:307`). **No existe `/api/reportes/kardex`.**

**Pregunta 2:** “¿Qué diferencia hay entre el SP del kardex y los de reportes?”

**Respuesta:** el kardex usa `sp_Movimientos_Listar` (`08_sp_movimientos.sql:307`), que devuelve el detalle de movimientos filtrable por producto y fechas. Los reportes agregados usan `sp_Reportes_MayoresSalidas` (`11_sp_reportes.sql:11`), `sp_Reportes_ConsumoPorArea` (`:40`) y `sp_Reportes_StockValorizado` (`:64`), invocados desde `repositories/reporte_repository.py:20,31,41`.

---

### Ficha 10 — Usuarios y Roles

#### Ubicación de los componentes

| Módulo | Componente | Template | Estilos |
|---|---|---|---|
| Usuarios | `frontend/src/app/features/usuarios/usuarios.ts` | `usuarios.html` | `usuarios.scss` |
| Roles | `frontend/src/app/features/roles/roles.ts` | `roles.html` | `roles.scss` |

#### Usuarios — signals del formulario

| Línea | Elemento |
|---|---|
| `usuarios.ts:59-63` | `busqueda`, `filtroEstado`, `filtroRol`, `pagina` |
| `usuarios.ts:92-98` | alta: `modalAlta`, `nombre`, `email`, `password`, `idRol`, `intentadoAlta`, `guardandoAlta` |
| `usuarios.ts:145-151` | edición: `modalEdicion`, `usuarioEditando`, `nombreEdicion`, `emailEdicion`, `activoEdicion`, `intentadoEdicion`, `guardandoEdicion` |
| `usuarios.ts:184-190` | roles: `modalRoles`, `usuarioRoles`, `rolesAsignados`, `permisosEfectivos`, `idRolSeleccionado`, `cargandoRoles`, `guardandoRol` |
| `usuarios.ts:199-204` | contraseña: `modalPassword`, `usuarioPassword`, `passwordNueva`, `confirmacionPassword`, `intentadoPassword`, `guardandoPassword` |

Métodos principales:

| Línea | Método |
|---|---|
| `usuarios.ts:231` | `ngOnInit()` |
| `usuarios.ts:288/297` | `abrirAlta`, `cerrarAlta` |
| `usuarios.ts:301` | `crearUsuario()` |
| `usuarios.ts:330/339/343` | `abrirEdicion`, `cerrarEdicion`, `guardarEdicion()` |
| `usuarios.ts:372/381/385/408` | `abrirRoles`, `cerrarRoles`, `agregarRol`, `quitarRol` |
| `usuarios.ts:446/454/458` | `abrirPassword`, `cerrarPassword`, `cambiarPassword()` |
| `usuarios.ts:485` | `desactivar(usuario)` |

Template de usuarios: tabla `usuarios.html:114`; alta `:220`/form `:226`; edición `:326`/form `:332`; roles `:419`; contraseña `:520`/form `:526`.

#### Roles — signals del formulario

| Línea | Elemento |
|---|---|
| `roles.ts:52-53` | `busqueda`, `filtroEstado` |
| `roles.ts:75-80` | `modalFormulario`, `rolEditando`, `nombre`, `descripcion`, `intentado`, `guardando` |
| `roles.ts:110-114` | `modalPermisos`, `rolPermisos`, `seleccionados`, `cargandoPermisos`, `guardandoPermisos` |

Métodos principales:

| Línea | Método |
|---|---|
| `roles.ts:142` | `ngOnInit()` |
| `roles.ts:165/173/181` | `abrirAlta`, `abrirEdicion`, `cerrarFormulario` |
| `roles.ts:185` | `guardar()` |
| `roles.ts:223/249` | `desactivar`, `reactivar` |
| `roles.ts:271/278` | `abrirPermisos`, `cerrarPermisos` |
| `roles.ts:286/298/302` | `alternarPermiso`, `marcarTodos`, `limpiarSeleccion` |
| `roles.ts:306` | `guardarPermisos()` |

Template de roles: tabla `roles.html:98`; formulario `:188`/form `:198`; modal de permisos `:253`.

#### Servicio Angular

| Línea | Método |
|---|---|
| `api.service.ts:300` | `cargarUsuarios(filtros?)` |
| `api.service.ts:314/320` | `crearUsuario`, `actualizarUsuario` |
| `api.service.ts:326` | `desactivarUsuario` |
| `api.service.ts:332` | `cambiarPasswordUsuario` |
| `api.service.ts:338/348/354` | `listarRolesUsuario`, `asignarRolUsuario`, `quitarRolUsuario` |
| `api.service.ts:362` | `cargarRoles` |
| `api.service.ts:375/381` | `crearRol`, `actualizarRol` |
| `api.service.ts:387` | `desactivarRol` |
| `api.service.ts:393` | `listarPermisosRol` |
| `api.service.ts:399` | `sincronizarPermisosRol` |
| `api.service.ts:428` | `cargarPermisos` |

#### Endpoints FastAPI

**Usuarios** → `backend/src/backend/apis/usuario_api.py` (router `:30`, prefijo `/api/usuarios`)

| Línea | Función |
|---|---|
| 35-36 | `listar(...)` |
| 57-58 | `obtener(id_usuario)` |
| 66-67 | `crear(datos)` |
| 75-76 | `actualizar(id_usuario, datos)` |
| 85-86 | `desactivar(id_usuario)` |
| 95-96 | `cambiar_contrasena(...)` |
| 106-107 | `roles(id_usuario)` |
| 115-116 | `permisos(id_usuario)` |
| 124-125 | `asignar(...)` |
| 135-138 | `quitar(...)` |

**Roles** → `backend/src/backend/apis/rol_api.py` (router `:28`, prefijo `/api/roles`)

| Línea | Función |
|---|---|
| 33-34 | `listar(...)` |
| 42-43 | `obtener(id_rol)` |
| 51-52 | `crear(datos)` |
| 60-61 | `actualizar(id_rol, datos)` |
| 70-71 | `desactivar(id_rol)` |
| 80-81 | `permisos(id_rol)` |
| 89-90 | `sincronizar(id_rol, ...)` |
| 100-101 | `asignar(...)` |
| 111-114 | `quitar(...)` |

**Permisos** → `backend/src/backend/apis/permiso_api.py` (router `:12`, prefijo `/api/permisos`, funciones `:18` y `:27`).

#### Service y Repository

| Capa | Archivo:línea |
|---|---|
| Service usuarios | `services/usuario_service.py:27,49,63,78,86,111,121` |
| Repository usuarios | `repositories/usuario_repository.py:46,66,86,109,130,161,172` |
| Service roles | `services/rol_service.py:29,42,51,64,70,76,89,103,117` |
| Repository roles | `repositories/rol_repository.py:38,48,61,82,90,95,106,117,131` |

#### Stored Procedures

| SP | Archivo:línea |
|---|---|
| `dbo.sp_Usuarios_ObtenerSesion` | `database/03_sp_usuarios.sql:12` |
| `dbo.sp_Usuarios_Obtener` | `database/03_sp_usuarios.sql:45` |
| `dbo.sp_Usuarios_Listar` | `database/03_sp_usuarios.sql:70` |
| `dbo.sp_Usuarios_Crear` | `database/03_sp_usuarios.sql:127` |
| `dbo.sp_Usuarios_Actualizar` | `database/03_sp_usuarios.sql:172` |
| `dbo.sp_Usuarios_Desactivar` | `database/03_sp_usuarios.sql:228` |
| `dbo.sp_Usuarios_CambiarPassword` | `database/03_sp_usuarios.sql:266` |
| `dbo.sp_Usuarios_ListarRoles` | `database/03_sp_usuarios.sql:285` |
| `dbo.sp_Usuarios_ListarPermisos` | `database/03_sp_usuarios.sql:299` |
| `dbo.sp_Usuarios_AsignarRol` | `database/03_sp_usuarios.sql:315` |
| `dbo.sp_Usuarios_QuitarRol` | `database/03_sp_usuarios.sql:340` |
| `dbo.sp_Roles_Listar` | `database/04_sp_roles_permisos.sql:11` |
| `dbo.sp_Roles_Obtener` | `database/04_sp_roles_permisos.sql:28` |
| `dbo.sp_Roles_Crear` | `database/04_sp_roles_permisos.sql:44` |
| `dbo.sp_Roles_Actualizar` | `database/04_sp_roles_permisos.sql:61` |
| `dbo.sp_Roles_Desactivar` | `database/04_sp_roles_permisos.sql:92` |
| `dbo.sp_Roles_ListarPermisos` | `database/04_sp_roles_permisos.sql:111` |
| `dbo.sp_Roles_AsignarPermiso` | `database/04_sp_roles_permisos.sql:125` |
| `dbo.sp_Roles_QuitarPermiso` | `database/04_sp_roles_permisos.sql:149` |
| `dbo.sp_Roles_SincronizarPermisos` | `database/04_sp_roles_permisos.sql:164` |
| `dbo.sp_Permisos_Listar` | `database/04_sp_roles_permisos.sql:198` |
| `dbo.sp_Permisos_Obtener` | `database/04_sp_roles_permisos.sql:211` |

**Regla de negocio:** la contraseña se hashea con Argon2id en Python (`backend/src/backend/security.py`) **antes** de llamar a `sp_Usuarios_Crear`. La cuenta semilla no se puede desactivar, cambiar de correo ni perder el rol ADMINISTRADOR (`52005` → 409).

#### Simulacro de examen

**Pregunta 1:** “¿Dónde se asignan los roles a un usuario y qué endpoint se usa?”

**Respuesta:** en el componente `usuarios.ts` (`abrirRoles` `:372`, `agregarRol` `:385`, `quitarRol` `:408`), que usan `ApiService.asignarRolUsuario` (`api.service.ts:348`) y `quitarRolUsuario` (`:354`). El endpoint es `apis/usuario_api.py:125` (`POST /api/usuarios/{id}/roles`) y `:138` (`DELETE`). El SP es `dbo.sp_Usuarios_AsignarRol` (`database/03_sp_usuarios.sql:315`) o `dbo.sp_Usuarios_QuitarRol` (`:340`).

**Pregunta 2:** “¿Dónde se editan los permisos de un rol?”

**Respuesta:** en `roles.ts`: `abrirPermisos` (`:271`), `alternarPermiso` (`:286`) y `guardarPermisos` (`:306`). El servicio es `api.service.ts:399` (`sincronizarPermisosRol`) y el endpoint `apis/rol_api.py:90` (`PUT /api/roles/{id}/permisos`), que ejecuta `dbo.sp_Roles_SincronizarPermisos` (`database/04_sp_roles_permisos.sql:164`).

---

## Anexo A — Catálogo de Stored Procedures

Fuente canónica: `backend/src/backend/repositories/procedimientos.py` (clase `Sp`, líneas 13–78). `PERMITIDOS` (`:81`) es la lista blanca: un SP que no esté allí no se ejecuta.

| Módulo | SP | Script |
|---|---|---|
| Usuarios | `sp_Usuarios_ObtenerSesion`, `Obtener`, `Listar`, `Crear`, `Actualizar`, `Desactivar`, `CambiarPassword`, `ListarRoles`, `ListarPermisos`, `AsignarRol`, `QuitarRol` | `03_sp_usuarios.sql` |
| Roles/Permisos | `sp_Roles_Listar`, `Obtener`, `Crear`, `Actualizar`, `Desactivar`, `ListarPermisos`, `AsignarPermiso`, `QuitarPermiso`, `SincronizarPermisos`, `sp_Permisos_Listar`, `Obtener` | `04_sp_roles_permisos.sql` |
| Categorías | `sp_Categorias_Listar`, `Obtener`, `Crear`, `Actualizar`, `Desactivar` | `05_sp_categorias.sql` |
| Productos | `sp_Productos_Listar`, `Obtener`, `Crear`, `Actualizar`, `Desactivar` | `06_sp_productos.sql` |
| Lotes | `sp_Lotes_ListarPorProducto`, `Obtener` | `07_sp_lotes.sql` |
| Movimientos | `sp_Movimientos_RegistrarEntrada`, `RegistrarSalida`, `Listar`, `Obtener` | `08_sp_movimientos.sql` |
| Áreas | `sp_Areas_Listar`, `Obtener`, `Crear`, `Actualizar`, `Desactivar` | `09_sp_areas.sql` |
| Alertas/Dashboard | `sp_Alertas_StockBajo`, `sp_Alertas_PorVencer`, `sp_Dashboard_Resumen` | `10_sp_alertas_dashboard.sql` |
| Reportes | `sp_Reportes_MayoresSalidas`, `ConsumoPorArea`, `StockValorizado` | `11_sp_reportes.sql` |
| Auditoría | `sp_Auditoria_Registrar` | `12_sp_auditoria.sql` |

**Instalador consolidado:** `database/INSTALAR_SIGIH.sql` contiene todos los scripts en orden (`00`–`19` + `99`). Verificación final: `database/99_verificar.sql`.

---

## Anexo B — Códigos de error de negocio

Clasificación: `backend/src/backend/repositories/errores_sql.py` (`clasificar`, línea 65). Mapeo a HTTP: `backend/src/backend/main.py`.

| Código | Significado | HTTP |
|---|---|---|
| `51009` | Producto con existencias (no se puede desactivar) | 409 |
| `511xx` | Entradas inválidas (cantidad, motivo, producto, lote) | 400/409 |
| `51201`–`51203` | Salida inválida: cantidad, motivo, producto | 400/422 |
| `51206` | Lote no encontrado | 404 |
| `51207` | Lote sin fecha de vencimiento | 400 |
| `51208` | **Lote vencido** (`fecha_vencimiento <= hoy`) | 409 |
| `51209` | **Stock insuficiente** (lote indicado o ningún lote FEFO alcanza) | 409 |
| `51402` | Categoría duplicada | 409 |
| `51403` | Categoría no encontrada | 404 |
| `51404` | Categoría con productos activos | 409 |
| `51502` | Área duplicada | 409 |
| `51503` | Área no encontrada | 404 |
| `51504` | **Área con movimientos registrados** | 409 |
| `52001`–`52003` | Datos de usuario inválidos / usuario no encontrado | 400/404 |
| `52004` | Último administrador activo | 409 |
| `52005` | **Cuenta semilla protegida** | 409 |
| `52103` | Rol protegido | 409 |
| `52104` | Permiso no encontrado | 404 |

---

## Anexo C — 20 preguntas rápidas de repaso

1. **¿Dónde está el formulario de login?** → `features/auth/login/login.html:72`.
2. **¿Qué servicio Angular llama al login?** → `AuthService.login` (`auth.service.ts:80`) → `ApiService.login` (`api.service.ts:243`).
3. **¿Qué SP usa el login?** → `dbo.sp_Usuarios_ObtenerSesion` (`03_sp_usuarios.sql:12`).
4. **¿Dónde se calculan las tarjetas del dashboard?** → `dashboard.ts:50-81` con `computed()`.
5. **¿Qué SP alimenta el dashboard?** → `dbo.sp_Dashboard_Resumen` (`10_sp_alertas_dashboard.sql:76`).
6. **¿Dónde está el modal de categorías?** → `categorias.html:213` y el form en `:214`.
7. **¿Qué código bloquea borrar una categoría con productos?** → `51404` en `sp_Categorias_Desactivar` (`05_sp_categorias.sql:90`).
8. **¿Dónde está el CRUD de áreas?** → `areas.ts` + `areas.html`; API `area_api.py:25-58`.
9. **¿Qué código impide desactivar un área con movimientos?** → `51504` en `sp_Areas_Desactivar` (`09_sp_areas.sql:81`).
10. **¿Dónde se listan los productos paginados?** → `productos.ts:234` → `api.service.ts:538` → `producto_api.py:30`.
11. **¿Por qué no se puede editar el stock desde Productos?** → `ProductoActualizar` no lo expone y usa `extra="forbid"` (`schemas/producto.py`).
12. **¿Dónde se consultan los lotes de un producto?** → `lotes.ts:106` → `api.service.ts:597` → `lote_api.py:15`.
13. **¿Se pueden crear lotes manualmente?** → No; se crean en `sp_Movimientos_RegistrarEntrada` (`08_sp_movimientos.sql:13`).
14. **¿Dónde está el formulario de entrada?** → `movimientos.html:266`, método `enviarEntrada` (`movimientos.ts:368`).
15. **¿Dónde está el formulario de salida?** → `movimientos.html:455`, método `enviarSalida` (`movimientos.ts:464`).
16. **¿Quién aplica FEFO?** → El SP `sp_Movimientos_RegistrarSalida` (`08_sp_movimientos.sql:196-220`), no el frontend.
17. **¿Qué SP procesa las alertas por vencer?** → `dbo.sp_Alertas_PorVencer` (`10_sp_alertas_dashboard.sql:48`).
18. **¿El kardex tiene endpoint propio?** → No; usa `GET /api/movimientos` (`movimiento_api.py:42`) y `sp_Movimientos_Listar` (`08_sp_movimientos.sql:307`).
19. **¿Dónde se asignan roles a un usuario?** → `usuarios.ts:385` → `api.service.ts:348` → `usuario_api.py:125` → `sp_Usuarios_AsignarRol` (`03_sp_usuarios.sql:315`).
20. **¿Dónde se sincronizan los permisos de un rol?** → `roles.ts:306` → `api.service.ts:399` → `rol_api.py:90` → `sp_Roles_SincronizarPermisos` (`04_sp_roles_permisos.sql:164`).

---

## Anexo D — Verificación rápida

```powershell
# 1. ¿Existe el archivo del componente?
Get-ChildItem frontend\src\app\features -Recurse -Include *.ts,*.html,*.scss

# 2. ¿Dónde está un endpoint?
Select-String -Path backend\src\backend\apis\*.py -Pattern "@router|^def "

# 3. ¿Qué SP usa un repository?
Select-String -Path backend\src\backend\repositories\*.py -Pattern "Sp\.|ejecutar_"

# 4. ¿Dónde está definido un SP?
Select-String -Path database\*.sql -Pattern "CREATE OR ALTER PROCEDURE dbo\.sp_"

# 5. ¿Qué llama el frontend?
Select-String -Path frontend\src\app\core\services\api.service.ts -Pattern "this\.http\.|`\$\{this\.base\}"
```

**Regla mental para el examen:**

```
Pantalla (features/…)
   → ApiService.metodo()  (core/services/api.service.ts)
      → @router.funcion()  (backend/…/apis/…_api.py)
         → service.funcion()  (backend/…/services/…_service.py)
            → repository.funcion()  (backend/…/repositories/…_repository.py)
               → EXEC dbo.sp_…   (database/0X_sp_….sql)
```

---

*Documento generado a partir del código fuente en la rama `rediseno_visual`. No se modificó ningún archivo de la aplicación.*
