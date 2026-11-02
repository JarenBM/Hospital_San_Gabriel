# SIGIH · Frontend

Aplicación Angular del **Sistema de Gestión de Inventario Hospitalario (SIGIH)** del
Hospital San Gabriel. Consume la API FastAPI del directorio `backend/` a través del
proxy de desarrollo `/api`.

## Requisitos

- **Node.js** `^20.19.0`, `^22.12.0` o `>=24.0.0`.
- **npm 11** (recomendado). Con npm 10.9.3 la instalación falla con
  `Cannot read properties of null (reading 'edgesOut')` por un bug de Arborist con
  las dependencias peer de Vitest. Use `npx --yes npm@11 install`.
- Backend SIGIH en ejecución sobre `http://127.0.0.1:8000`.

## Puesta en marcha

### 1. Backend

```powershell
cd backend
uv run uvicorn backend.main:app --reload
```

Compruebe `http://127.0.0.1:8000/docs`. Los endpoints de la API requieren token,
salvo `POST /api/auth/login`.

Credenciales de desarrollo sembradas por la base de datos:

- Correo: `admin.desarrollo@sigih.test`
- Contraseña: `Admin.2026!`

### 2. Frontend

```powershell
cd frontend
npx --yes npm@11 install
npx --yes npm@11 start
```

La aplicación queda en `http://localhost:4200/`. El archivo `proxy.conf.json`
redirige `/api` a `http://127.0.0.1:8000`, de modo que el código usa rutas
relativas (`/api/productos`) sin problemas de CORS en desarrollo.

## Scripts

| Comando | Descripción |
| --- | --- |
| `npm start` | Servidor de desarrollo con proxy (`ng serve`). |
| `npm run build` | Compila a `dist/frontend` en modo producción. |
| `npm run watch` | Compilación incremental en modo desarrollo. |
| `npm test` | Pruebas unitarias con Vitest y jsdom. |

## Estructura

```
src/app/
├── core/
│   ├── guards/
│   │   ├── auth.guard.ts          # rutas privadas + espera de restauración
│   │   ├── role.guard.ts          # permisos/roles declarados en data
│   │   └── guest.guard.ts         # aleja a los autenticados de /login
│   ├── interceptors/
│   │   ├── auth.interceptor.ts    # Authorization: Bearer <token>
│   │   └── error.interceptor.ts   # 401/403/409/422/5xx → ApiError + notificación
│   ├── services/
│   │   ├── api.service.ts         # fachada HTTP + estado reactivo (Recurso<T>)
│   │   ├── auth.service.ts        # login, logout, permisos y rol en signals
│   │   ├── session-store.ts       # token y usuario en signals
│   │   ├── notificacion.service.ts
│   │   └── token-storage.ts       # persistencia en localStorage
│   └── utils/
│       ├── api-error.ts           # normalización de errores HTTP
│       └── formato.ts             # moneda, números y fechas es-PE
├── features/
│   ├── auth/login/                # formulario de inicio de sesión
│   ├── dashboard/                 # resumen del inventario
│   ├── errors/forbidden/          # 403
│   ├── errors/not-found/          # 404
│   └── modulos/                   # marcador "en construcción" por módulo
├── models/                        # contratos espejo de los schemas Pydantic
├── shared/components/layout/
│   ├── shell.ts|html|scss         # navbar + sidebar responsive
│   └── navegacion.ts              # catálogo de rutas, iconos y permisos
├── app.config.ts                  # providers, interceptores y restauración de sesión
└── app.routes.ts                  # rutas lazy con guards
```

## Capa de datos

### Modelos

`src/app/models/` replica uno a uno los schemas Pydantic del backend
(`Usuario`, `Rol`, `Categoria`, `Producto`, `Lote`, `Movimiento`,
`Area`, `Alerta`, `Dashboard` y `Reporte`). Importe siempre desde el barrel:

```ts
import type { ProductoListado, MovimientoListado } from './models';
```

> Pydantic v2 serializa `Decimal` como **string** (`"12.50"`). Los campos
> monetarios se tipan como `DecimalString`; conviértalos con `Number(...)` antes
> de operar.

### `ApiService`

Fachada única para la API. Cachea el estado de cada recurso en un `Recurso<T>` con
signals (`datos`, `cargando`, `error`, `cargado`) y deriva valores con `computed`
(`productosActivos`, `stockTotal`, `totalAlertas`, `valorInventario`, etc.).

```ts
private readonly api = inject(ApiService);

// Estado reactivo (signals)
api.productos.datos();
api.productos.cargando();
api.productosActivos();

// Peticiones
api.cargarProductos({ solo_activos: true }).subscribe();
api.registrarEntrada({ id_producto: 1, cantidad: 5, motivo: 'Compra' }).subscribe();
api.login(email, password).subscribe();
```

Al cerrar sesión (o recibir un 401) se limpian todas las cachés para no dejar
inventario visible en memoria.

### Interceptores

- **`authInterceptor`**: añade `Authorization: Bearer <token>` a toda petición
  `/api`, excepto el login.
- **`errorInterceptor`**: normaliza la respuesta a `ApiError` y notifica:
  - `401` → cierra la sesión (salvo credenciales inválidas en el login) y
    redirige a `/login?returnUrl=...` para volver a la pantalla solicitada.
  - `403` → acceso denegado por RBAC.
  - `409` → conflicto de estado.
  - `422` → errores de validación resumidos campo a campo.
  - `5xx` / `0` → fallo del servidor o API inaccesible.

El error se reemite como `ApiError`, de modo que cada página puede detener su
spinner o marcar el formulario sin perder el detalle.

## Autenticación y navegación

### `AuthService`

Envuelve `SessionStore` y `ApiService` y expone el estado de la sesión como
signals de solo lectura:

| Miembro | Descripción |
| --- | --- |
| `isAutenticado` | Hay token guardado y la sesión es utilizable. |
| `rolActual` | Primer rol del usuario (`ADMINISTRADOR`, `ALMACEN`, `CONSULTA`...). |
| `esAdmin` | El usuario tiene el rol `ADMINISTRADOR`. |
| `permisosMap` | `Map<string, true>` para consultas O(1) de permisos. |
| `permisos` / `roles` | Listas reactivas devueltas por `GET /api/auth/me`. |
| `rutaInicio` | Dashboard (admin), movimientos (almacén) o productos (consulta). |
| `cargando` / `error` | Estado del formulario de login. |

Métodos: `login(email, password)`, `logout()`, `restaurarSesion()`,
`tienePermiso(codigo)`, `tieneAlguno(...)`, `tieneTodos(...)` y `tieneRol(rol)`.

La restauración se lanza en `provideAppInitializer` y **no bloquea** el arranque.
Los guards llaman a `esperarRestauracion()` si hay una hidratación en curso, para
no decidir con la sesión a medio cargar tras recargar el navegador.

### Guards

| Guard | Uso |
| --- | --- |
| `authGuard` | Protege el layout privado; sin token → `/login?returnUrl=...`. |
| `guestGuard` | Si ya hay sesión, `/login` redirige al inicio del rol. |
| `roleGuard` | Autoriza con `data: { permiso }`, `{ permisos, modo }` o `{ roles }`. Si falla → `/403`. |

```ts
{
  path: 'usuarios',
  canActivate: [roleGuard],
  data: { permiso: 'usuarios:gestionar' },
}
```

### Layout y páginas

`Shell` combina un navbar superior con notificaciones y menú de perfil, y un
sidebar responsive. Las opciones se filtran con `computed()` sobre
`AuthService.permisosMap`, de modo que desaparecen al cambiar de usuario. El
catálogo vive en `shared/components/layout/navegacion.ts`.

Los módulos aún no implementados (productos, lotes, movimientos, reportes,
usuarios, roles...) reutilizan `ModuloPendiente` con `titulo`, `descripcion` e
`icono` recibidos por `withComponentInputBinding`. `/403` y `/404` son páginas
independientes; cualquier URL desconocida termina en `/404`.

## Estilos

Bootstrap 5.3 y Bootstrap Icons se cargan globalmente desde `angular.json`.
`src/styles.scss` define la paleta SIGIH (variables `--sigih-*`), utilidades
(`.sigih-card`, `.sigih-tabla`, `.sigih-badge-permiso`) y los ajustes de foco y
accesibilidad.

## Notas de desarrollo

- Angular **21.2** se eligió porque Angular 22 exige Node `>=22.22.3` y el entorno
  actual usa Node 22.20.0.
- El login usa **Signal Forms** (`@angular/forms/signals`), experimental en
  Angular 21; el modelo, la carga y el error son signals.
- La paginación de listados queda diferida a la siguiente fase del frontend.
- Los módulos sin implementar muestran la página "En construcción" descrita
  arriba; no son enlaces muertos.
