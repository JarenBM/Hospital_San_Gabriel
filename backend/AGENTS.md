# AGENTS.md

## Proyecto
SIGIH — Sistema de Gestión de Inventario Hospitalario. Backend en **Python + FastAPI**.

## Estado actual y alcance
Estructura por capas en `src/backend/` (`main.py`, `apis/`, `services/`, `repositories/`, `schemas/`), conexión pyodbc en `config.py` + `database.py` y módulos de **categorías**, **productos**, **inventario**, **alertas** y **autenticación**:

- Categorías: `GET/POST /api/categorias`, `GET/PUT/DELETE /api/categorias/{id}`. El `PUT` acepta `activo` para reactivar.
- Productos: `GET/POST /api/productos`, `GET/PUT/DELETE /api/productos/{id}`; el listado admite `busqueda`, `id_categoria` y `solo_activos`.
- Inventario: `GET /api/productos/{id}/lotes`, `GET /api/movimientos` (filtros `id_producto`, `tipo_movimiento`, `id_area`, `desde`, `hasta`, `busqueda`; paginación opcional), `GET /api/movimientos/motivos-entrada`, `POST /api/movimientos/entradas`, `POST /api/movimientos/salidas`, `GET /api/areas`. No hay CRUD de lotes: el stock solo se mueve con entradas y salidas.
- Alertas (solo lectura): `GET /api/alertas/stock-bajo`, `GET /api/alertas/por-vencer?dias=30`, `GET /api/alertas/vencidos`, `GET /api/alertas/resumen?desde=&hasta=`.
- Autenticación: `POST /api/auth/login` (OAuth2 password form: `username` = correo, `password`) y `GET /api/auth/me`. Emite JWT HS256 de 60 minutos.

El modelo completo de la base (incluido `sp_Areas_Listar`) se instala con `database/INSTALAR_SIGIH.sql`.

Sin commits, sin tests, sin linter ni CI.

Alcance inmediato: categorías, productos, inventario, alertas y autenticación. **No implementar registro público de usuarios, CRUD de usuarios, roles avanzados, refresh tokens, recuperación de contraseñas ni dashboard propio todavía.**

## Comandos
- `uv sync` — crea/actualiza `.venv` desde `uv.lock`
- `uv run uvicorn src.backend.main:app` — **único comando de inicio**, ejecutado **dentro de `backend/`**. Sin `--reload` por decisión del equipo: tras cambiar código hay que reiniciar.
- `uv add <pkg>` / `uv add --dev <pkg>` — no editar dependencias a mano sin actualizar `uv.lock`
- `uv run python <archivo>` — siempre vía `uv run`; un `python` global no tiene las dependencias
- No tocar `[project.scripts]`: `uv run backend` apunta al stub de `__init__.py` y no arranca la API.

## Estructura objetivo (modelo visto en clase)
```
src/backend/
  main.py          # instancia FastAPI, CORS, incluye routers
  apis/            # endpoints / routers
  services/        # lógica de negocio
  repositories/    # ejecutan procedimientos almacenados vía pyodbc
  schemas/         # modelos Pydantic (request/response)
```
Flujo: `main.py -> apis -> services -> repositories`. Respetar la dirección: un `api` no llama a un `repository` directamente.

El layout `src/` es obligatorio: el paquete debe seguir en `src/backend/` porque el backend `uv_build` y el script `backend = "backend:main"` dependen de eso.

## Base de datos
- Microsoft SQL Server, base de datos `SIGIH`.
- Conexión con **pyodbc**. **No usar ORM** (ni SQLAlchemy).
- Credenciales solo desde `.env`; nunca escritas en el código. `.env` está en `.gitignore` — no lo agregues al repo. Si se necesita, documentar las variables en `.env.example` (sin valores reales).
- El nombre exacto del driver ODBC va en `.env`; no asumirlo.
- Los **repositories** ejecutan los procedimientos almacenados ya existentes.
- **No crear ni modificar tablas ni stored procedures desde el backend.**
- `obtener_conexion()` usa `autocommit=True` a propósito: sin eso, al cerrar la conexión ODBC hace rollback y las escrituras de los SP se pierden en silencio.
- Los errores de SQL Server se clasifican en `repositories/errores_sql.py` (`clasificar()`); cada repository decide qué excepción de `errors.py` lanzar y `main.py` la mapea a HTTP. `services` y `apis` no conocen pyodbc.
- `sp_Categorias_Listar` y `sp_Productos_Listar` devuelven también registros inactivos si no se filtra; el filtrado por `activo` es responsabilidad del cliente.
- Los listados de productos, usuarios y movimientos aceptan `pagina` y `tamano` (máximo 100). Sin ellos devuelven todo, para no romper consumidores antiguos. Con paginación, la API añade `X-Total-Count` y el SP calcula `COUNT(*) OVER () AS total`; `repositories/base.total_de()` lee esa columna.
- Productos usa **dos** schemas de respuesta y no se deben unificar: `Producto` (11 columnas de `sp_Productos_Obtener`) y `ProductoListado` (14 columnas de `sp_Productos_Listar`, que añade `categoria`, `stock_total` y `stock_disponible`). Ambos ignoran la columna extra `total`.
- `sp_Productos_Actualizar` no recibe `@maneja_lotes` ni `@requiere_vencimiento`: esos dos flags solo se fijan al crear. No los añadas al schema de `PUT`, serían ignorados.
- **Las transacciones de stock viven en los SP**, no en Python: `sp_Movimientos_RegistrarEntrada` y `sp_Movimientos_RegistrarSalida` usan `BEGIN TRAN`/`COMMIT` con `XACT_ABORT` y `ROLLBACK` en el `CATCH`. El repository solo ejecuta `EXEC`, sin `commit()` ni transacción propia. No dupliques esa lógica.
- `id_usuario` **no viaja en el body**: entradas y salidas lo toman del usuario autenticado por el token. `EntradaCrear` y `SalidaCrear` usan `extra="forbid"`, así que enviar `id_usuario` responde 422. Los SP siguen exigiendo que el usuario exista y esté activo (`dbo.Usuarios.activo=1`).
- `SalidaCrear.id_lote` es **opcional**: si llega `null`, `sp_Movimientos_RegistrarSalida` aplica FEFO y elige el lote vigente con vencimiento más próximo que cubra la cantidad (si ningún lote individual alcanza responde 51209 → 409). El resultado devuelve `id_lote` y `numero_lote`.
- Un lote vence al terminar el día anterior: `fecha_vencimiento <= hoy` es VENCIDO y no se puede despachar (`51208`), ni suma al stock disponible.
- `dbo.Usuarios` se llena con `sp_Usuarios_Crear` (requiere `password_hash`). No crear usuarios de prueba automáticamente. La cuenta semilla `admin.desarrollo@sigih.test` no se puede desactivar, cambiar de correo ni perder el rol ADMINISTRADOR (`52005` → 409).
- Los `Decimal` (precio, valor referencial) se serializan en el JSON como **string** (`"15.00"`), no como número: es el comportamiento de Pydantic v2 y ya está así en Productos. No lo cambies solo en un módulo; el frontend debe convertirlo.
- `sp_Alertas_PorVencer` no tiene cota inferior: con `dias=0` devuelve todos los lotes vencidos con existencias (incluidos los que vencen hoy), por antiguos que sean. Filtra `p.activo=1`, así que los lotes vencidos de productos inactivos no aparecen. El resumen (`sp_Dashboard_Resumen`) cuenta los próximos a vencer entre mañana y 30 días.

## Autenticación
- `POST /api/auth/login` usa `OAuth2PasswordRequestForm`: el formulario llega como `application/x-www-form-urlencoded` con `username` (el correo) y `password`. Swagger lo aprovecha con el botón Authorize; el frontend Angular debe enviarlo igual, no como JSON.
- Contraseñas con Argon2id (`argon2-cffi`, `PasswordHasher`). Un hash mal formado se trata como credencial inválida (401), nunca como 500.
- Tokens con `pyjwt` y HS256. Payload `sub` = correo, más `iat` y `exp`. El sujeto es el correo para reutilizar `sp_Usuarios_ObtenerSesion` sin crear SP nuevos; si el correo cambiara, los tokens emitidos dejan de servir.
- `JWT_SECRET` y `JWT_EXPIRACION_MINUTOS` viven solo en `.env`. `config.py` valida al importar: la API no arranca si falta el secreto o mide menos de 32 caracteres. **Nunca poner un secreto por defecto en el código.**
- Cada petición protegida vuelve a consultar al usuario: si se desactiva, su token deja de servir de inmediato. No hay lista de revocación ni refresh token.
- Un único mensaje, "Credenciales inválidas", para correo inexistente, usuario inactivo y contraseña incorrecta.
- `password_hash` nunca sale en una respuesta: `UsuarioAutenticado` se construye campo a campo.
- Protegidas: `POST`/`PUT`/`DELETE` de categorías y productos, `POST` de entradas y salidas, y `GET /api/auth/me`. Los `GET` de consulta siguen públicos.
- `python-multipart` es obligatorio para el formulario OAuth2; no quitarlo de las dependencias.
- Sin registro público, roles, refresh tokens ni recuperación de contraseña.

## Convenciones
- CORS debe permitir `http://localhost:4200` (frontend Angular).
- Código simple y legible: evitar capas, ORMs o librerías innecesarias.
- Python `>=3.14` (`.python-version`); no bajar la versión sin motivo.
- Sin runner de tests instalado: `uv run pytest` falla hasta `uv add --dev pytest` (y `httpx` para el `TestClient` de FastAPI).

## Actualización FASE BUILD (2026-11)

Esta sección reemplaza las restricciones de alcance anteriores.

- El SQL de instalación vive en `database/` (raíz), con scripts idempotentes
  `00`–`19` y verificación `99`. Usar `sqlcmd -f 65001` para leer UTF-8 y
  `-I` si se ejecuta DML manual sobre `Lotes`.
- El backend solo ejecuta stored procedures a través de
  `repositories/base.py` y el catálogo `repositories/procedimientos.py`.
  No hay SQL directo ni nombres de tablas en Python.
- La conexión usa el usuario `sigih_app`: `GRANT EXECUTE ON SCHEMA::dbo` y
  `DENY SELECT/INSERT/UPDATE/DELETE ON SCHEMA::dbo`.
- RBAC con roles `ADMINISTRADOR`, `ALMACEN`, `CONSULTA` y permisos
  `modulo:accion`. Todos los endpoints, incluidos los GET, exigen permiso.
- Endpoints nuevos: `/api/usuarios`, `/api/roles`, `/api/permisos`,
  CRUD completo de `/api/areas`, `/api/dashboard` y `/api/reportes`.
- `GET /api/auth/me` devuelve también `roles` y `permisos`.
- Auditoría: usuarios, roles, catálogos y productos usan
  `sp_Auditoria_Registrar` best-effort; **entradas y salidas** insertan su
  auditoría (`id_usuario`, `accion`, `modulo`, `id_registro`, `id_area`,
  `detalle`) dentro de la misma transacción del SP, por lo que la cobertura es
  total. El listado de auditoría sigue diferido.
- Conflictos 409: producto con existencias, categoría con productos activos,
  área con movimientos registrados, cuenta semilla protegida y último
  administrador activo.
- `sp_Productos_Actualizar` acepta `@activo`, pero el schema `PUT` no lo
  expone: el backend envía `NULL` para conservar el estado.
