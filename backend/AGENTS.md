# AGENTS.md

## Proyecto
SIGIH — Sistema de Gestión de Inventario Hospitalario. Backend en **Python + FastAPI**.

## Estado actual y alcance
Estructura por capas en `src/backend/` (`main.py`, `apis/`, `services/`, `repositories/`, `schemas/`), conexión pyodbc en `config.py` + `database.py` y módulos de **categorías**, **productos**, **inventario**, **alertas** y **autenticación**:

- Categorías: `GET/POST /api/categorias`, `GET/PUT/DELETE /api/categorias/{id}`. El `PUT` acepta `activo` para reactivar.
- Productos: `GET/POST /api/productos`, `GET/PUT/DELETE /api/productos/{id}`; el listado admite `busqueda`, `id_categoria` y `solo_activos`.
- Inventario: `GET /api/productos/{id}/lotes`, `GET /api/movimientos` (filtros `id_producto`, `tipo_movimiento`, `id_area`, `desde`, `hasta`), `POST /api/movimientos/entradas`, `POST /api/movimientos/salidas`, `GET /api/areas`. No hay CRUD de lotes: el stock solo se mueve con entradas y salidas.
- Alertas (solo lectura): `GET /api/alertas/stock-bajo`, `GET /api/alertas/por-vencer?dias=30`, `GET /api/alertas/vencidos`, `GET /api/alertas/resumen?desde=&hasta=`.
- Autenticación: `POST /api/auth/login` (OAuth2 password form: `username` = correo, `password`) y `GET /api/auth/me`. Emite JWT HS256 de 60 minutos.

`sp_Area_Listar` ya está instalado en la base (lo crea `database/SIGIH_Areas_Listar.sql`) y sigue pendiente incorporarlo al script maestro de instalación de SIGIH.

Sin commits, sin tests, sin linter ni CI.

Alcance inmediato: categorías, productos, inventario, alertas y autenticación. **No implementar registro público de usuarios, CRUD de usuarios, roles avanzados, refresh tokens, recuperación de contraseñas ni dashboard propio todavía.**

## Comandos
- `uv sync` — crea/actualiza `.venv` desde `uv.lock`
- `uv run uvicorn backend.main:app` — **único comando de inicio** (desde la raíz del proyecto). Sin `--reload` por decisión del equipo: tras cambiar código hay que reiniciar.
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
- `sp_Categoria_Listar` y `sp_Producto_Listar` devuelven también registros inactivos si no se filtra; el filtrado por `activo` es responsabilidad del cliente.
- Productos usa **dos** schemas de respuesta y no se deben unificar: `Producto` (11 columnas de `sp_Producto_Obtener`) y `ProductoListado` (14 columnas de `sp_Producto_Listar`, que añade `categoria`, `stock_total` y `stock_disponible`).
- `sp_Producto_Actualizar` no recibe `@activo`, `@maneja_lotes` ni `@requiere_vencimiento`: no existe reactivación de productos y esos dos flags solo se fijan al crear. No los añadas al schema de `PUT`, serían ignorados.
- **Las transacciones de stock viven en los SP**, no en Python: `sp_Entrada_Registrar` y `sp_Salida_Registrar` usan `BEGIN TRAN`/`COMMIT` con `XACT_ABORT` y `ROLLBACK` en el `CATCH`. El repository solo ejecuta `EXEC`, sin `commit()` ni transacción propia. No dupliques esa lógica.
- `id_usuario` **no viaja en el body**: entradas y salidas lo toman del usuario autenticado por el token. `EntradaCrear` y `SalidaCrear` usan `extra="forbid"`, así que enviar `id_usuario` responde 422. Los SP siguen exigiendo que el usuario exista y esté activo (`dbo.Usuarios.activo=1`).
- `dbo.Usuarios` se llena con `sp_Usuario_Crear` (requiere `password_hash`). No crear usuarios de prueba automáticamente.
- Los `Decimal` (precio, valor referencial) se serializan en el JSON como **string** (`"15.00"`), no como número: es el comportamiento de Pydantic v2 y ya está así en Productos. No lo cambies solo en un módulo; el frontend debe convertirlo.
- `sp_Lote_Vencimientos` no tiene cota inferior de fecha: con `dias=0` devuelve todos los lotes vencidos con existencias, por antiguos que sean. Filtra `p.activo=1`, así que los lotes vencidos de productos inactivos no aparecen. El resumen (`sp_Dashboard_Resumen`) siempre cuenta los próximos a vencer en una ventana fija de 30 días.

## Autenticación
- `POST /api/auth/login` usa `OAuth2PasswordRequestForm`: el formulario llega como `application/x-www-form-urlencoded` con `username` (el correo) y `password`. Swagger lo aprovecha con el botón Authorize; el frontend Angular debe enviarlo igual, no como JSON.
- Contraseñas con Argon2id (`argon2-cffi`, `PasswordHasher`). Un hash mal formado se trata como credencial inválida (401), nunca como 500.
- Tokens con `pyjwt` y HS256. Payload `sub` = correo, más `iat` y `exp`. El sujeto es el correo para reutilizar `sp_Usuario_ObtenerPorEmail` sin crear SP nuevos; si el correo cambiara, los tokens emitidos dejan de servir.
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
