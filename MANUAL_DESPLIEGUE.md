# Manual de despliegue — SIGIH · Hospital San Gabriel

Guía para instalar y ejecutar el **Sistema de Gestión de Inventario Hospitalario
(SIGIH)** desde cero en un equipo nuevo.

> **¿Solo quieres levantarlo rápido?** Consulta el
> [`README.md`](README.md#inicio-rápido-1015-minutos). Este manual explica el
> detalle de cada paso y cómo resolver problemas.

| Dato | Valor |
|---|---|
| Proyecto | SIGIH — Hospital San Gabriel |
| Arquitectura | 3 capas: SQL Server · FastAPI · Angular |
| Sistema operativo de referencia | Windows 10/11 (comandos en PowerShell) |
| Ámbito | Ejecución local en un solo equipo (`127.0.0.1`) |
| Tiempo estimado | 10–15 min si los requisitos ya están instalados; 40–60 min desde cero |

---

## Contenido

1. [Antes de empezar](#1-antes-de-empezar)
2. [Requisitos](#2-requisitos)
3. [Obtener el proyecto](#3-obtener-el-proyecto)
4. [Base de datos](#4-base-de-datos)
5. [Backend](#5-backend)
6. [Frontend](#6-frontend)
7. [Verificación integral](#7-verificación-integral)
8. [Problemas comunes](#8-problemas-comunes)
9. [Anexos](#9-anexos)

---

## 1. Antes de empezar

El sistema tiene tres capas que deben estar activas **en este orden**:

```text
┌──────────────────────────┐        ┌──────────────────────────┐        ┌──────────────────────────┐
│  SQL Server              │        │  FastAPI (uvicorn)       │        │  Angular 22              │
│  Base de datos SIGIH     │◀──────▶│  http://127.0.0.1:8000   │◀──────▶│  http://localhost:4200   │
│  Instancia .\SQLEXPRESS  │  pyodbc│  Login JWT + RBAC        │  /api  │  Signals + Bootstrap 5   │
└──────────────────────────┘        └──────────────────────────┘        └──────────────────────────┘
      Scripts de database/                  carpeta backend/                  carpeta frontend/
```

| Componente | Tecnología | Dirección local | Carpeta |
|---|---|---|---|
| Base de datos | SQL Server Express/Developer | `.\SQLEXPRESS` | `database/` |
| API | Python 3.14 + FastAPI + uvicorn | `http://127.0.0.1:8000` | `backend/` |
| Interfaz web | Angular 22 Standalone + Signals | `http://localhost:4200` | `frontend/` |

Reglas del despliegue:

1. **No se puede saltar capas.** Si la base no responde, la API falla; si la API
   no está activa, el frontend muestra errores en las peticiones `/api`.
2. **El frontend debe arrancarse con `npm start`**, no abriendo `dist/`
   directamente: el proxy `/api` solo existe en el servidor de desarrollo.
3. **El backend se ejecuta desde `backend/`**. Desde la raíz, el módulo `src` no
   es importable.

### 1.1 Ruta recomendada

Este manual prioriza **una sola vía** para evitar confusiones:

| Tema | Vía recomendada |
|---|---|
| Scripts SQL | Un solo archivo: `database/INSTALAR_SIGIH.sql` |
| Cliente SQL | `sqlcmd` (incluido con SSMS) |
| Backend | `uv run uvicorn src.backend.main:app` |
| Frontend | `npm install` + `npm start` |

Las alternativas (SSMS, scripts individuales, compilación de producción) están
en los anexos.

---

## 2. Requisitos

### 2.1 Resumen

| # | Componente | Versión / requisito | Verificación |
|---|---|---|---|
| 1 | Node.js | `^22.22.3`, `^24.15.0` o `>=26.0.0` | `node -v` |
| 2 | npm | 10.9.9 o superior | `npm -v` |
| 3 | Python | 3.14 (lo fija `backend/.python-version`) | `python --version` |
| 4 | uv | Última versión estable | `uv --version` |
| 5 | SQL Server | Express o Developer, en ejecución | `Get-Service *MSSQL*` |
| 6 | Cliente SQL | `sqlcmd` **o** SSMS | `sqlcmd -?` |
| 7 | Controlador ODBC | **ODBC Driver 18 for SQL Server** | `Get-OdbcDriver` |
| 8 | Git (opcional) | Para clonar el repositorio | `git --version` |

> **Angular 22 no admite Node 22.20.0 ni anteriores.** El CLI aborta con
> `The Angular CLI requires a minimum Node.js version of v22.22.3 or v24.15.0 or
> v26.0.0`. Actualice Node antes de instalar el frontend.
>
> **El ODBC Driver 18 es imprescindible:** el backend arma la cadena de conexión
> con `DRIVER={ODBC Driver 18 for SQL Server}`. Sin él, la API no conecta.

### 2.2 Node.js y npm

```powershell
winget install OpenJS.NodeJS.LTS
```

Cierre y vuelva a abrir la terminal, luego verifique:

```powershell
node -v    # v22.22.3+, v24.15+ o v26+
npm -v     # 10.9.9 o superior
```

Si npm falla al instalar con `Cannot read properties of null (reading
'edgesOut')`, actualícelo:

```powershell
npm install -g npm@11
```

### 2.3 Python y uv

```powershell
winget install astral-sh.uv
```

`uv` descarga la versión de Python que fija el proyecto (3.14) la primera vez que
se ejecuta `uv sync`. Requiere conexión a internet en ese momento.

```powershell
python --version
uv --version
```

### 2.4 SQL Server

1. Instale **SQL Server Express** o **Developer**.
2. Elija **Autenticación de SQL Server y Windows** y defina una contraseña para
   `sa` (no la usa la aplicación, pero sirve para administración).
3. Use la instancia con nombre por defecto: **`SQLEXPRESS`**.

```powershell
Get-Service | Where-Object { $_.Name -like 'MSSQL*' } | Select-Object Name, Status
sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT @@VERSION"
```

> Si instaló una instancia **predeterminada**, use `localhost` en todos los
> comandos y cambie `DB_SERVER` en `backend/.env`.

### 2.5 Cliente SQL: `sqlcmd` o SSMS

- **`sqlcmd`** viene con SQL Server y con SSMS. Verifique con `sqlcmd -?`.
- **SSMS** (interfaz gráfica):
  <https://learn.microsoft.com/sql/ssms/download-sql-server-management-studio-ssms>
- **VS Code:** extensión **SQL Server (mssql)**, identificador `ms-mssql.mssql`.

### 2.6 Controlador ODBC 18

Descargue e instale **ODBC Driver 18 for SQL Server**:
<https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server>

```powershell
Get-OdbcDriver | Where-Object { $_.Name -like '*SQL Server*' } | Select-Object Name
```

Debe aparecer `ODBC Driver 18 for SQL Server`.

### 2.7 Verificación conjunta

```powershell
node -v
npm -v
python --version
uv --version
sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT @@VERSION"
Get-OdbcDriver | Where-Object { $_.Name -like '*SQL Server*' } | Select-Object Name
```

Si algún comando falla, resuélvalo antes de continuar.

---

## 3. Obtener el proyecto

### 3.1 Clonar

```powershell
git clone <URL_DEL_REPOSITORIO> Hospital_San_Gabriel
cd Hospital_San_Gabriel
```

Sin Git: copie la carpeta completa **sin** `node_modules`, `.venv`, `dist` ni
`.angular`.

> A partir de aquí, `<proyecto>` representa la carpeta donde clonó el
> repositorio. Los comandos usan rutas relativas, así que funcionan en cualquier
> ubicación.

### 3.2 Estructura relevante

```text
Hospital_San_Gabriel/
├── README.md                  # inicio rápido
├── MANUAL_DESPLIEGUE.md       # este documento
├── database/
│   ├── INSTALAR_SIGIH.sql     # ⭐ instalación completa (00 a 17 + verificación)
│   ├── 00_crear_base.sql
│   ├── ...
│   └── 99_verificar.sql
├── backend/
│   ├── .env                   # ⭐ incluido: credenciales de desarrollo
│   ├── .env.example           # plantilla de referencia
│   ├── .python-version        # 3.14
│   ├── pyproject.toml
│   ├── uv.lock
│   └── src/backend/           # main.py, apis, services, ...
└── frontend/
    ├── package.json
    ├── proxy.conf.json        # /api → http://127.0.0.1:8000
    └── src/app/               # core, shared, features
```

### 3.3 Qué viene incluido

- **`backend/.env`** se versiona a propósito, con credenciales de desarrollo
  funcionales. No hay que crearlo ni editarlo para levantar el proyecto.
- **No se versionan** `node_modules/`, `.venv/`, `dist/` ni `.angular/`: se
  regeneran con `npm install` y `uv sync`.
- **`uv.lock` y `package-lock.json`** sí se versionan: fijan versiones exactas
  para que la instalación sea reproducible.

---

## 4. Base de datos

### 4.1 Instalación recomendada: un solo archivo

`database/INSTALAR_SIGIH.sql` contiene todo el proceso en orden: creación de la
base, tablas, RBAC, stored procedures, catálogos, roles, administrador, login
`sigih_app` y la verificación final.

Desde la raíz del proyecto:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -b -I -f 65001 -i database\INSTALAR_SIGIH.sql
```

**Resultado esperado:** la última línea es

```text
INSTALACIÓN SIGIH FINALIZADA
Si no aparecieron errores, la base SIGIH está lista.
```

Parámetros del comando:

| Parámetro | Función |
|---|---|
| `-S .\SQLEXPRESS` | Instancia de SQL Server |
| `-E` | Autenticación de Windows |
| `-C` | Confía en el certificado del servidor (desarrollo local) |
| `-b` | Aborta si un bloque produce error |
| `-I` | Activa `QUOTED_IDENTIFIER` (lo exigen los índices filtrados) |
| `-f 65001` | Lee el archivo como UTF-8 (conserva acentos) |
| `-i archivo` | Archivo de entrada |

> **Contraseña de `sigih_app`:** el archivo define
> `DECLARE @password NVARCHAR(128) = N'Sigih.App.2026!';`, que coincide con
> `DB_PASSWORD` del `.env` incluido. Si la cambia en el SQL, cámbiela también en
> `backend/.env`.
>
> **Si la base ya existía**, ejecutar el instalador **cambia** la contraseña del
> login `sigih_app` por la del archivo. Ajuste la línea antes de ejecutarlo.

**Alternativa con SSMS**

1. Conéctese a `.\SQLEXPRESS` con *Windows Authentication*.
2. Abra `database/INSTALAR_SIGIH.sql`.
3. Pulse `F5` y revise la pestaña **Mensajes**.

> Los scripts están en UTF-8. Si SSMS muestra acentos corruptos (`mǸdico`), no
> ejecute: use `sqlcmd` con `-f 65001`.

### 4.2 Verificar la instalación

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT name FROM sys.databases WHERE name = N'SIGIH'"
sqlcmd -S .\SQLEXPRESS -E -C -d SIGIH -Q "SELECT COUNT(*) AS tablas FROM sys.tables"
```

Resultados esperados:

| Comprobación | Resultado |
|---|---|
| Base de datos | Una fila: `SIGIH` |
| Tablas | `11` |
| Stored procedures | `71` |
| Roles | `3` (`ADMINISTRADOR`, `ALMACEN`, `CONSULTA`) |
| Administrador | `admin.desarrollo@sigih.test` activo |

Para una verificación completa puede ejecutar de nuevo el bloque final:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -f 65001 -i database\99_verificar.sql
```

> La base recién instalada **no contiene productos**: solo catálogos, roles,
> permisos y el administrador. Es correcto que el dashboard muestre 0 productos.

---

## 5. Backend

### 5.1 Configuración: `.env` incluido

El repositorio incluye `backend/.env` con valores funcionales:

```dotenv
DB_SERVER=.\SQLEXPRESS
DB_NAME=SIGIH
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_USER=sigih_app
DB_PASSWORD=Sigih.App.2026!
JWT_SECRET=<64 caracteres>
JWT_EXPIRACION_MINUTOS=60
```

**Solo debe editarlo si:**

| Situación | Cambio |
|---|---|
| Su instancia no es `.\SQLEXPRESS` | Ajuste `DB_SERVER` (`localhost`, `.\MSSQLSERVER`, etc.) |
| Cambió la contraseña en `INSTALAR_SIGIH.sql` | Ajuste `DB_PASSWORD` con el mismo valor |
| Va a desplegar en producción | Genere un `JWT_SECRET` nuevo |

Para generar un secreto nuevo:

```powershell
cd backend
uv run python -c "import secrets; print(secrets.token_urlsafe(48))"
```

> `JWT_SECRET` debe tener **32 caracteres o más**. Si falta o es corto, la API
> aborta al iniciar con un mensaje explícito.

### 5.2 Instalar dependencias

Desde la raíz del proyecto:

```powershell
cd backend
uv sync
```

**Resultado esperado:** `Resolved ...` e `Installed ...`, y se crea
`backend/.venv`.

### 5.3 Arrancar la API

En la **misma terminal** (ya está dentro de `backend/`):

```powershell
uv run uvicorn src.backend.main:app
```

**Resultado esperado:**

```text
Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

> **Comando oficial:** `uv run uvicorn src.backend.main:app`, sin `--reload`.
> Debe ejecutarse **dentro de `backend/`**: desde la raíz, `src` no es
> importable. Deje la terminal abierta.

### 5.4 Verificar la API

1. Abra <http://127.0.0.1:8000/docs>: debe cargar Swagger UI con los módulos de
   autenticación, usuarios, roles, categorías, productos, lotes, movimientos,
   áreas, alertas, dashboard y reportes.

2. Pruebe el login desde PowerShell:

```powershell
$login = Invoke-RestMethod -Method Post `
  -Uri 'http://127.0.0.1:8000/api/auth/login' `
  -ContentType 'application/x-www-form-urlencoded' `
  -Body @{ username = 'admin.desarrollo@sigih.test'; password = 'Admin.2026!' }

$login.token_type
$login.access_token.Substring(0, 24) + '...'

Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/auth/me' `
  -Headers @{ Authorization = "Bearer $($login.access_token)" } |
  Format-List nombre, email, roles, permisos
```

**Resultado esperado:** `bearer`, un token truncado y el usuario
`Administrador Desarrollo` con rol `ADMINISTRADOR`.

---

## 6. Frontend

### 6.1 Instalar dependencias

Abra una **segunda** terminal. Desde la raíz del proyecto:

```powershell
cd frontend
npm install
```

Esto instala Angular 22, Bootstrap 5, Bootstrap Icons, RxJS, TypeScript y
Vitest en `frontend/node_modules/`.

- Alternativa reproducible con el lockfile: `npm ci`.
- Si npm falla con `edgesOut`, use `npm install -g npm@11` y reintente.

### 6.2 Arrancar el servidor de desarrollo

En la **misma terminal** (ya está dentro de `frontend/`):

```powershell
npm start
```

`npm start` ejecuta `ng serve`, que:

- Compila la aplicación en modo desarrollo.
- Aplica `proxy.conf.json`: `/api` → `http://127.0.0.1:8000`.
- Publica la app en **`http://localhost:4200`**.

**Resultado esperado:** `Local: http://localhost:4200/`.

> No hace falta instalar Angular CLI global: se usa la versión local de
> `node_modules`.

### 6.3 Verificar el frontend

1. Abra <http://localhost:4200>: debe aparecer el login de SIGIH.
2. Inicie sesión con `admin.desarrollo@sigih.test` / `Admin.2026!`.
3. Confirme la versión del framework:

```powershell
npx ng version
```

Debe mostrar **Angular 22.2.x** y **Angular CLI 22.2.x**.

### 6.4 Compilación de producción (opcional)

```powershell
npm run build
```

Genera el bundle en `frontend/dist/frontend/`. Para la evaluación basta con
`npm start`; este paso solo es necesario si va a publicar la app en un servidor
web.

---

## 7. Verificación integral

### 7.1 Credenciales

| Uso | Usuario | Contraseña |
|---|---|---|
| Aplicación web | `admin.desarrollo@sigih.test` | `Admin.2026!` |
| SQL Server (solo API) | `sigih_app` | `Sigih.App.2026!` |

> El administrador lo crea `database/16_admin_inicial.sql` y se guarda con hash
> Argon2id. Cambie la contraseña tras el primer inicio de sesión desde
> **Usuarios**.

### 7.2 Checklist de las 3 capas

Ejecute en orden. No avance si la capa anterior falla.

| # | Capa | Comprobación | Acción | Resultado esperado |
|---|---|---|---|---|
| 1 | SQL Server | Servicio activo | `Get-Service *MSSQL*` | `Running` |
| 2 | SQL Server | Conexión | `sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT 1"` | `1` |
| 3 | SQL Server | Base creada | `SELECT name FROM sys.databases WHERE name='SIGIH'` | `SIGIH` |
| 4 | SQL Server | Modelo completo | `INSTALAR_SIGIH.sql` | 11 tablas, 71 SPs, 3 roles, admin |
| 5 | Backend | Dependencias | `uv sync` | Sin errores |
| 6 | Backend | Arranque | `uv run uvicorn src.backend.main:app` | `Uvicorn running on ...:8000` |
| 7 | Backend | Swagger | Abrir `/docs` | Todos los routers |
| 8 | Backend | Login | `POST /api/auth/login` | `access_token` + `bearer` |
| 9 | Backend | Sesión | `GET /api/auth/me` | Usuario y permisos |
| 10 | Frontend | Dependencias | `npm install` | `node_modules/` y `ng version` 22.2.x |
| 11 | Frontend | Arranque | `npm start` | `Local: http://localhost:4200/` |
| 12 | Frontend | Login visual | Iniciar sesión | Dashboard con menú completo |
| 13 | Integración | Datos reales | Crear categoría y producto | Aparecen en tabla y dashboard |

### 7.3 Flujo funcional mínimo

1. Inicie sesión.
2. Confirme que el **dashboard** muestra productos, alertas y valor estimado.
3. Cree una **categoría** y verifique el toast de éxito.
4. Cree un **producto** asignado a esa categoría.
5. Registre una **entrada** en **Movimientos**.
6. Verifique que **Lotes**, **Alertas** y **Reportes** reflejan los datos.
7. Cierre sesión y vuelva a entrar para confirmar la persistencia.

Si los 7 pasos funcionan, las tres capas están correctamente conectadas.

---

## 8. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `The Angular CLI requires a minimum Node.js version` | Node anterior a 22.22.3 | Actualice Node y abra una terminal nueva |
| `Cannot read properties of null (reading 'edgesOut')` | Bug de npm 10.9.3 con Vitest | `npm install -g npm@11` |
| `uv : no se reconoce como nombre de un cmdlet` | `uv` no está en el PATH | Reinstale uv y abra una terminal nueva |
| `ModuleNotFoundError: No module named 'src'` | Comando ejecutado desde la raíz | `cd backend` antes de `uv run uvicorn ...` |
| `RuntimeError: Faltan DB_USER y DB_PASSWORD` | `.env` ausente o incompleto | Restaurar `backend/.env` desde el repositorio |
| `RuntimeError: JWT_SECRET ...` | Secreto ausente o de menos de 32 caracteres | Generar uno nuevo (paso 5.1) |
| `pyodbc.Error: ('IM002', ...)` | Falta el ODBC Driver 18 | Instalarlo (paso 2.6) |
| `Login failed for user 'sigih_app'` | `DB_PASSWORD` no coincide con el instalador | Ajustar `.env` o reejecutar el instalador con la misma clave |
| Error `51801` al ejecutar el script 17 suelto | Falta `APP_PASSWORD` | Usar `INSTALAR_SIGIH.sql` o `sqlcmd -v` (anexo 9.1) |
| Acentos corruptos (`mǸdico`) en la base | Scripts leídos sin UTF-8 | Reejecutar con `sqlcmd ... -f 65001` |
| `'ng' no se reconoce...` | Angular CLI no está global | Usar `npm start` |
| `Port 4200 is already in use` | Otro proceso ocupa el puerto | `npm start -- --port 4201` |
| `Port 8000 is already in use` | Otro uvicorn activo | Cerrar el proceso anterior |
| `/api` responde `404` | Backend detenido | Arrancar la API y usar `npm start` |
| Error de CORS | Se abrió `dist/` sin proxy | Usar `http://localhost:4200` con `npm start` |
| Login responde `401` | Credenciales incorrectas o seed no ejecutado | Revisar usuario/contraseña y `INSTALAR_SIGIH.sql` |
| La API responde `500` | `sigih_app` sin permisos o SPs faltantes | Reejecutar `INSTALAR_SIGIH.sql` |

---

## 9. Anexos

### 9.1 Ejecución individual de los scripts (mantenimiento)

El instalador único es la vía recomendada. Si necesita ejecutar los 19 scripts
por separado, el orden es obligatorio:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\00_crear_base.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\01_tablas_base.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\02_rbac_tablas.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\03_sp_usuarios.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\04_sp_roles_permisos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\05_sp_categorias.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\06_sp_productos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\07_sp_lotes.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\08_sp_movimientos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\09_sp_areas.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\10_sp_alertas_dashboard.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\11_sp_reportes.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\12_sp_auditoria.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\13_wrappers_legacy.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\14_seed_catalogos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\15_seed_rbac.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\16_admin_inicial.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\17_permisos_app.sql -v APP_PASSWORD="Sigih.App.2026!"
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\99_verificar.sql
```

| # | Archivo | Contenido |
|---|---|---|
| 1 | `00_crear_base.sql` | Crea la base `SIGIH` |
| 2 | `01_tablas_base.sql` | Tablas base e índices |
| 3 | `02_rbac_tablas.sql` | Roles, permisos, asignaciones y auditoría |
| 4 | `03_sp_usuarios.sql` | SPs de usuarios |
| 5 | `04_sp_roles_permisos.sql` | SPs de roles y permisos |
| 6 | `05_sp_categorias.sql` | SPs de categorías |
| 7 | `06_sp_productos.sql` | SPs de productos |
| 8 | `07_sp_lotes.sql` | SPs de lotes |
| 9 | `08_sp_movimientos.sql` | Entradas y salidas (transaccionales) |
| 10 | `09_sp_areas.sql` | SPs de áreas hospitalarias |
| 11 | `10_sp_alertas_dashboard.sql` | Alertas y resumen del dashboard |
| 12 | `11_sp_reportes.sql` | Kardex, mayores salidas y stock valorizado |
| 13 | `12_sp_auditoria.sql` | Registro de auditoría |
| 14 | `13_wrappers_legacy.sql` | Wrappers con nombres antiguos |
| 15 | `14_seed_catalogos.sql` | Catálogos iniciales |
| 16 | `15_seed_rbac.sql` | Roles y permisos |
| 17 | `16_admin_inicial.sql` | Administrador inicial |
| 18 | `17_permisos_app.sql` | Login/usuario `sigih_app` |
| 19 | `99_verificar.sql` | Solo lectura: comprueba la instalación |

Todos son **idempotentes**: se pueden repetir sin duplicar datos.

**Ejecución del script 17 en SSMS (modo SQLCMD):**

```sql
:setvar APP_PASSWORD "Sigih.App.2026!"
:r "C:\ruta\del\proyecto\database\17_permisos_app.sql"
```

### 9.2 Puertos y direcciones

| Servicio | Dirección | Puerto |
|---|---|---|
| SQL Server | `.\SQLEXPRESS` | Instancia con nombre |
| API FastAPI | `http://127.0.0.1:8000` | 8000 |
| Swagger UI | `http://127.0.0.1:8000/docs` | 8000 |
| Frontend Angular | `http://localhost:4200` | 4200 |

### 9.3 Variables de entorno

| Variable | Obligatoria | Valor de desarrollo | Descripción |
|---|---|---|---|
| `DB_SERVER` | Sí | `.\SQLEXPRESS` | Instancia de SQL Server |
| `DB_NAME` | Sí | `SIGIH` | Base de datos |
| `DB_DRIVER` | Sí | `ODBC Driver 18 for SQL Server` | Driver ODBC |
| `DB_USER` | Sí | `sigih_app` | Usuario de aplicación (solo EXECUTE) |
| `DB_PASSWORD` | Sí | `Sigih.App.2026!` | Debe coincidir con el instalador SQL |
| `JWT_SECRET` | Sí | 64 caracteres | Firma de tokens; mínimo 32 |
| `JWT_EXPIRACION_MINUTOS` | Sí | `60` | Vigencia del token |

### 9.4 Notas de seguridad

- `backend/.env` **se versiona a propósito** porque el proyecto es académico y
  debe funcionar al clonar. Son credenciales de desarrollo.
- Si el proyecto se publica o despliega, **genere un `JWT_SECRET` nuevo** y
  cambie la contraseña de `sigih_app`.
- El usuario `sigih_app` solo ejecuta procedimientos de `dbo`; no lee ni escribe
  tablas directamente.
- Cambie la contraseña del administrador tras la primera sesión.
- No use `--reload` en la entrega: el comando oficial es
  `uv run uvicorn src.backend.main:app`.
- Para producción real, sirva el frontend compilado con un servidor web y use
  HTTPS.

### 9.5 Referencias

- [`README.md`](README.md) — inicio rápido.
- [`database/README.md`](database/README.md) — scripts, orden y reglas de negocio.
- [`backend/README.md`](backend/README.md) — configuración de la API.
- [`frontend/README.md`](frontend/README.md) — estructura y capa de datos.
- `backend/src/backend/main.py` — routers, CORS y manejo de errores HTTP.
