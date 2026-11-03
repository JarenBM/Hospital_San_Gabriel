# Manual de despliegue — SIGIH · Hospital San Gabriel

Guía técnica para instalar y ejecutar el **Sistema de Gestión de Inventario Hospitalario (SIGIH)** desde cero en un dispositivo nuevo (por ejemplo, el equipo del laboratorio de evaluación).

| Dato | Valor |
|---|---|
| Proyecto | SIGIH — Hospital San Gabriel |
| Arquitectura | 3 capas: SQL Server · FastAPI · Angular |
| Sistema operativo de referencia | Windows 10/11 (los comandos se muestran en PowerShell) |
| Ámbito | Ejecución local en un solo equipo (`127.0.0.1`) |
| Documentos relacionados | `database/README.md`, `backend/README.md`, `frontend/README.md` |

---

## Contenido

1. [Arquitectura y alcance](#1-arquitectura-y-alcance)
2. [Requisitos previos del nuevo dispositivo](#2-requisitos-previos-del-nuevo-dispositivo)
3. [Obtención y estructura del proyecto](#3-obtención-y-estructura-del-proyecto)
4. [Configuración y ejecución de la base de datos](#4-configuración-y-ejecución-de-la-base-de-datos)
5. [Ejecución del backend (FastAPI)](#5-ejecución-del-backend-fastapi)
6. [Ejecución del frontend (Angular)](#6-ejecución-del-frontend-angular)
7. [Verificación y acceso inicial](#7-verificación-y-acceso-inicial)
8. [Solución de problemas](#8-solución-de-problemas)
9. [Anexos](#9-anexos)

---

## 1. Arquitectura y alcance

El sistema se compone de tres capas que deben estar activas **en este orden**: base de datos → backend → frontend.

```text
┌──────────────────────────┐        ┌──────────────────────────┐        ┌──────────────────────────┐
│  SQL Server              │        │  FastAPI (uvicorn)       │        │  Angular 21              │
│  Base de datos SIGIH     │◀──────▶│  http://127.0.0.1:8000   │◀──────▶│  http://localhost:4200   │
│  Instancia .\SQLEXPRESS  │  pyodbc│  Login JWT + RBAC        │  /api  │  Signals + Bootstrap 5   │
└──────────────────────────┘        └──────────────────────────┘        └──────────────────────────┘
      Scripts de database/                  carpeta backend/                  carpeta frontend/
```

| Componente | Tecnología | Dirección local | Carpeta |
|---|---|---|---|
| Base de datos | SQL Server Express/Developer | `.\SQLEXPRESS` (instancia con nombre) | `database/` |
| API | Python + FastAPI + uvicorn | `http://127.0.0.1:8000` | `backend/` |
| Interfaz web | Angular 21 Standalone + Signals | `http://localhost:4200` | `frontend/` |

> **Supuesto de despliegue:** las tres capas corren en la misma máquina. El frontend usa rutas relativas `/api` y el archivo `frontend/proxy.conf.json` las redirige a `http://127.0.0.1:8000`, por lo que no hay problemas de CORS en desarrollo.

---

## 2. Requisitos previos del nuevo dispositivo

### 2.1 Resumen de requisitos

| # | Componente | Versión / requisito | Verificación |
|---|---|---|---|
| 1 | Node.js | `^20.19.0`, `^22.12.0` o `>=24.0.0` | `node -v` |
| 2 | npm | 10.9.3 o superior (se recomienda npm 11) | `npm -v` |
| 3 | Python | 3.11 o superior (el proyecto fija 3.14) | `python --version` |
| 4 | uv | Última versión estable | `uv --version` |
| 5 | SQL Server | Express o Developer, en ejecución | `Get-Service *MSSQL*` |
| 6 | Cliente SQL | SSMS **o** extensión SQL Server de VS Code | — |
| 7 | Controlador ODBC | **ODBC Driver 18 for SQL Server** | `Get-OdbcDriver` |
| 8 | Git (opcional) | Para clonar el repositorio | `git --version` |

> El **ODBC Driver 18** es imprescindible: el backend se conecta con `pyodbc` y `backend/src/backend/config.py` construye la cadena con `DRIVER={ODBC Driver 18 for SQL Server}`. Sin él, la API no inicia sesión contra la base.

### 2.2 Node.js y npm

1. Instale Node.js LTS desde <https://nodejs.org/> (o con `winget install OpenJS.NodeJS.LTS`).
2. Cierre y vuelva a abrir la terminal.
3. Verifique:

```powershell
node -v    # v20.19.x, v22.12.x o v24.x o superior
npm -v
```

> **Nota sobre npm:** con npm 10.9.3 puede aparecer el error `Cannot read properties of null (reading 'edgesOut')` al instalar las dependencias del frontend (bug de Arborist con las dependencias peer de Vitest). En ese caso use `npx --yes npm@11 install`; el proyecto fue validado con npm 11.

### 2.3 Python y uv

1. Instale Python 3.11 o superior desde <https://www.python.org/downloads/>. Marque **“Add python.exe to PATH”**.
2. Instale `uv`:

```powershell
winget install astral-sh.uv
# Alternativa oficial:
# powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

3. Verifique:

```powershell
python --version
uv --version
```

> **Versión de Python:** `backend/pyproject.toml` exige `>=3.14` y `backend/.python-version` fija `3.14`. `uv` descarga y usa esa versión automáticamente la primera vez (requiere internet). Si el equipo estará sin conexión, instale Python 3.14 y ejecute `uv python install 3.14` **antes** de trasladar el equipo.

### 2.4 SQL Server (Express o Developer)

1. Instale **SQL Server Express** o **SQL Server Developer** desde el instalador oficial de Microsoft.
2. Durante la instalación elija **Autenticación de SQL Server y Windows** y defina una contraseña para `sa` (no la usará la aplicación, pero es útil para administración).
3. Use la instancia con nombre por defecto: **`SQLEXPRESS`**.
4. Confirme que el servicio está en ejecución:

```powershell
Get-Service | Where-Object { $_.Name -like 'MSSQL*' } | Select-Object Name, Status
```

5. Confirme la conexión (autenticación de Windows):

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT @@VERSION"
```

> Si instaló la edición **Developer con instancia predeterminada**, use `localhost` en lugar de `.\SQLEXPRESS` en todos los comandos y ajuste `DB_SERVER` en el `.env` del backend.

### 2.5 SQL Server Management Studio (SSMS) o VS Code

Elija una de las dos opciones:

- **SSMS:** descárguelo desde <https://learn.microsoft.com/sql/ssms/download-sql-server-management-studio-ssms>. Es la opción recomendada para ejecutar los scripts con comodidad.
- **VS Code:** instale la extensión **SQL Server (mssql)**, identificador `ms-mssql.mssql`.

### 2.6 Controlador ODBC 18

1. Descargue **ODBC Driver 18 for SQL Server** desde <https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server>.
2. Instálelo con las opciones por defecto.
3. Verifique:

```powershell
Get-OdbcDriver | Where-Object { $_.Name -like '*SQL Server*' } | Select-Object Name
```

Debe aparecer `ODBC Driver 18 for SQL Server`.

### 2.7 Checklist de requisitos

```powershell
node -v
npm -v
python --version
uv --version
sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT @@VERSION"
Get-OdbcDriver | Where-Object { $_.Name -like '*SQL Server*' } | Select-Object Name
```

---

## 3. Obtención y estructura del proyecto

### 3.1 Copia del proyecto

Con Git:

```powershell
git clone <URL_DEL_REPOSITORIO> Hospital_San_Gabriel
cd Hospital_San_Gabriel
```

Sin Git: copie la carpeta completa del proyecto (sin `node_modules`, sin `.venv`, sin `dist`) al disco local, por ejemplo `C:\SIGIH\Hospital_San_Gabriel`.

> **Importante:** `backend/.env` no se versiona (está en `.gitignore`). Deberá crearlo en el nuevo equipo según el paso 5.1. Tampoco copie `backend/.venv/` ni `frontend/node_modules/`: se regeneran en el nuevo entorno.

### 3.2 Estructura relevante

```text
Hospital_San_Gabriel/
├── database/                  # scripts SQL (00–17 + 99)
│   ├── INSTALAR_SIGIH.sql     # ⭐ instalación completa en un solo archivo
│   ├── 00_crear_base.sql
│   ├── ...
│   ├── 17_permisos_app.sql
│   └── 99_verificar.sql
├── backend/
│   ├── .env.example           # plantilla de configuración
│   ├── .python-version        # 3.14
│   ├── pyproject.toml
│   ├── uv.lock
│   └── src/backend/           # paquete backend (main.py, apis, services, ...)
└── frontend/
    ├── package.json
    ├── proxy.conf.json        # /api → http://127.0.0.1:8000
    └── src/app/               # core, shared, features
```

---

## 4. Configuración y ejecución de la base de datos

### 4.1 Instalación rápida: un solo archivo

Para compartir el proyecto con un compañero **no es necesario ejecutar los 19 scripts uno por uno**. El archivo **`database/INSTALAR_SIGIH.sql`** contiene todo el proceso en orden: creación de la base, tablas, RBAC, stored procedures, catálogos, roles, administrador, login `sigih_app` y la verificación final.

**En SSMS**

1. Conéctese a `.\SQLEXPRESS` con *Windows Authentication*.
2. Abra `database/INSTALAR_SIGIH.sql` y pulse **F5**.
3. Revise **Messages**: debe terminar con `INSTALACIÓN SIGIH FINALIZADA` y no mostrar errores en rojo.

**Con sqlcmd**

```powershell
cd C:\SIGIH\Hospital_San_Gabriel
sqlcmd -S .\SQLEXPRESS -E -C -b -I -f 65001 -i database\INSTALAR_SIGIH.sql
```

> **Contraseña de `sigih_app`:** el archivo define `DECLARE @password NVARCHAR(128) = N'Sigih.App.2026!';`. Debe coincidir con `DB_PASSWORD` de `backend/.env`. Si la base ya existía, ejecutar el archivo cambia esa contraseña: ajuste la línea antes de ejecutarlo.
>
> El archivo es **idempotente** y no borra datos. Los pasos 4.2 a 4.5 describen la ejecución individual de los scripts, útil para mantenimiento o para entender el orden.

### 4.2 Orden estricto de ejecución

La carpeta `database/` contiene **19 scripts**: los **18 de construcción** (`00` a `17`) y el **`99` de verificación**. Deben ejecutarse **exactamente en este orden**; cada bloque depende del anterior.

| # | Archivo | Contenido |
|---|---|---|
| 1 | `00_crear_base.sql` | Crea la base `SIGIH` (idempotente) |
| 2 | `01_tablas_base.sql` | Tablas base e índices |
| 3 | `02_rbac_tablas.sql` | Roles, permisos, asignaciones y auditoría |
| 4 | `03_sp_usuarios.sql` | Stored Procedures de usuarios |
| 5 | `04_sp_roles_permisos.sql` | Stored Procedures de roles y permisos |
| 6 | `05_sp_categorias.sql` | Stored Procedures de categorías |
| 7 | `06_sp_productos.sql` | Stored Procedures de productos |
| 8 | `07_sp_lotes.sql` | Stored Procedures de lotes |
| 9 | `08_sp_movimientos.sql` | Entradas y salidas (transaccionales) |
| 10 | `09_sp_areas.sql` | Stored Procedures de áreas hospitalarias |
| 11 | `10_sp_alertas_dashboard.sql` | Alertas y resumen del dashboard |
| 12 | `11_sp_reportes.sql` | Kardex, mayores salidas, consumo y stock valorizado |
| 13 | `12_sp_auditoria.sql` | Registro de auditoría |
| 14 | `13_wrappers_legacy.sql` | Wrappers con nombres antiguos |
| 15 | `14_seed_catalogos.sql` | Catálogos iniciales (categorías y áreas) |
| 16 | `15_seed_rbac.sql` | Roles `ADMINISTRADOR`, `ALMACEN`, `CONSULTA` y permisos |
| 17 | `16_admin_inicial.sql` | Usuario administrador inicial |
| 18 | `17_permisos_app.sql` | Login/usuario `sigih_app` con permisos mínimos |
| 19 | `99_verificar.sql` | **Solo lectura**: comprueba la instalación |

> **Regla de oro:** no ejecute `99_verificar.sql` hasta haber ejecutado `00`–`17`. El script `17` es el único que requiere una variable (`APP_PASSWORD`), explicada en el paso 4.4.

### 4.3 Opción A — Ejecución secuencial en SSMS

1. Abra **SSMS** y conéctese a:
   - **Nombre del servidor:** `.\SQLEXPRESS` (o `localhost` si usa instancia predeterminada).
   - **Autenticación:** *Windows Authentication*.
2. Cree una carpeta de trabajo y confirme que ve las bases del servidor en el *Object Explorer*.
3. Para **cada archivo, en el orden de la tabla 4.2**:
   1. `Archivo → Abrir → Archivo…` (o `Ctrl+O`) y seleccione el `.sql`.
   2. Pulse **Ejecutar** (`F5`).
   3. Revise la pestaña **Messages**: debe ver el `PRINT` de confirmación (por ejemplo `Base de datos SIGIH lista.`) y **ningún mensaje en rojo**.
   4. Cierre la pestaña antes de abrir el siguiente archivo para no confundir resultados.
4. Al terminar `17_permisos_app.sql`, ejecute `99_verificar.sql` y compare la salida con el paso 4.5.

> **Codificación de acentos:** los scripts están en UTF-8 y contienen textos como `médico` o `Hospitalización`. Si al abrir un archivo en SSMS ve caracteres corruptos (`mǸdico`, `Ã©`), **no lo ejecute**: use la opción B (`sqlcmd -f 65001`), que fuerza UTF-8 y evita guardar textos corruptos en la base.

#### Ejecución del script 17 en SSMS (obligatorio)

`17_permisos_app.sql` exige la variable `APP_PASSWORD`. En SSMS debe activar el **modo SQLCMD**:

1. Menú **Query → SQLCMD Mode** (debe quedar marcado).
2. Abra una **nueva** ventana de consulta conectada a `.\SQLEXPRESS`.
3. Pegue y ejecute (ajuste la ruta y la contraseña):

```sql
:setvar APP_PASSWORD "Sigih.App.2026!"
:r "C:\SIGIH\Hospital_San_Gabriel\database\17_permisos_app.sql"
```

4. Verifique el mensaje `17_permisos_app.sql ejecutado.`

> Si olvida el modo SQLCMD o la variable, el script falla deliberadamente con el error `51801` para no crear el usuario con contraseña vacía. Es el comportamiento esperado, no un fallo de la base.

> **Anote la contraseña elegida**: debe ser exactamente la misma que `DB_PASSWORD` en `backend/.env` (paso 5.1). Si la cambia después, vuelva a ejecutar el script 17 con el nuevo valor y actualice el `.env`.

### 4.4 Opción B — Ejecución secuencial con `sqlcmd` (recomendada)

Desde la raíz del proyecto, en PowerShell:

```powershell
cd C:\SIGIH\Hospital_San_Gabriel

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

Significado de los parámetros:

| Parámetro | Función |
|---|---|
| `-S .\SQLEXPRESS` | Instancia de SQL Server |
| `-E` | Autenticación de Windows |
| `-C` | Confía en el certificado del servidor (desarrollo local) |
| `-b` | Aborta con código de error si un script falla |
| `-f 65001` | Lee los archivos como UTF-8 (conserva acentos) |
| `-i archivo` | Archivo de entrada |
| `-v APP_PASSWORD="..."` | Variable requerida por el script 17 |

> Todos los scripts son **idempotentes** (tablas con `IF OBJECT_ID(...) IS NULL` y procedimientos con `CREATE OR ALTER`), por lo que se pueden volver a ejecutar sin duplicar datos.

### 4.5 Validación de la base de datos

1. Confirme que la base existe:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT name, create_date FROM sys.databases WHERE name = N'SIGIH'"
```

2. Cuente las tablas del modelo (deben ser **11**):

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -d SIGIH -Q "SELECT COUNT(*) AS tablas FROM sys.tables"
```

3. Ejecute la verificación completa (si no lo hizo en el paso anterior):

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -f 65001 -i database\99_verificar.sql
```

**Resultado esperado de `99_verificar.sql`:**

| Bloque | Resultado esperado |
|---|---|
| Tablas base y RBAC | 11 tablas: `AreasHospitalarias`, `Auditoria`, `Categorias`, `Lotes`, `Movimientos`, `Permisos`, `Productos`, `Roles`, `RolesPermisos`, `Usuarios`, `UsuariosRoles` |
| Stored procedures canónicos | Lista completa de SPs (`sp_Usuarios_*`, `sp_Productos_*`, `sp_Movimientos_*`, etc.), sin faltantes |
| RBAC | 3 roles (`ADMINISTRADOR`, `ALMACEN`, `CONSULTA`) con sus conteos de permisos y `total_permisos = 16` |
| Administrador inicial | `admin.desarrollo@sigih.test`, `activo = 1`, rol `ADMINISTRADOR` |
| Usuario de aplicación | `sigih_app` con `GRANT EXECUTE` sobre `dbo` y `DENY SELECT/INSERT/UPDATE/DELETE` sobre `dbo` |
| Conteos | Categorías y áreas con datos sembrados; productos, lotes, movimientos y usuarios según el estado inicial |

> La base recién instalada **no contiene productos**: solo catálogos, roles, permisos y el administrador. Es correcto que el dashboard muestre 0 productos hasta que se registren.

---

## 5. Ejecución del backend (FastAPI)

### 5.1 Crear el archivo `.env`

El backend **no arranca** sin `backend/.env`. Cree el archivo a partir de la plantilla:

```powershell
cd C:\SIGIH\Hospital_San_Gabriel\backend
Copy-Item .env.example .env
```

Genere un secreto JWT seguro:

```powershell
uv run python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Edite `backend/.env` y complete los valores:

```dotenv
# Conexión a SQL Server (instancia local, sin puerto explícito)
DB_SERVER=.\SQLEXPRESS
DB_NAME=SIGIH
DB_DRIVER=ODBC Driver 18 for SQL Server

# Credenciales del usuario de aplicación creado por database/17_permisos_app.sql
DB_USER=sigih_app
DB_PASSWORD=Sigih.App.2026!

# Autenticación JWT
JWT_SECRET=<pegar aquí el valor generado>
JWT_EXPIRACION_MINUTOS=60
```

Reglas obligatorias:

- `DB_PASSWORD` debe coincidir **exactamente** con el `APP_PASSWORD` usado al ejecutar `17_permisos_app.sql`.
- `JWT_SECRET` debe tener **32 caracteres o más**; si falta o es corto, la API aborta al iniciar con un mensaje explícito.
- `DB_SERVER` debe ser `.\SQLEXPRESS` para la instancia con nombre (o `localhost` para una instancia predeterminada).
- **Nunca** versione `.env` ni use el usuario `sa` para la aplicación.

### 5.2 Instalar dependencias de Python

```powershell
cd C:\SIGIH\Hospital_San_Gabriel\backend
uv sync
```

`uv sync` crea `backend/.venv` e instala las dependencias fijadas en `uv.lock` (FastAPI, uvicorn, pyodbc, PyJWT, argon2-cffi, python-dotenv y python-multipart). Para una instalación estrictamente reproducible puede usar `uv sync --frozen`.

> Si el equipo estará sin internet durante la evaluación, ejecute `uv sync` con conexión **antes** de la demo: así las dependencias quedan en la caché y en `.venv`.

### 5.3 Arranque oficial del backend

Desde la carpeta `backend/`:

```powershell
cd C:\SIGIH\Hospital_San_Gabriel\backend
uv run uvicorn src.backend.main:app
```

> **Comando oficial de la cátedra.** Use exactamente `uv run uvicorn src.backend.main:app`.
>
> ⚠️ **No agregue `--reload`.** El servidor debe levantarse en modo normal, sin recarga automática.

Notas técnicas:

- El comando debe ejecutarse **dentro de `backend/`**: desde la raíz del repositorio el módulo `src` no es importable. El paquete también responde a `backend.main:app`, que es el nombre que aparece en el docstring de `main.py`; ambos apuntan al mismo `app`.
- **Puerto por defecto:** `8000` → `http://127.0.0.1:8000`.
- Deje esta terminal abierta: si se cierra, la API se detiene.

### 5.4 Comprobación del backend

1. Abra <http://127.0.0.1:8000/docs>. Debe cargar Swagger UI con los módulos de autenticación, usuarios, roles, categorías, productos, lotes, movimientos, áreas, alertas, dashboard y reportes.
2. Compruebe el login y la sesión desde PowerShell:

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

**Resultado esperado:** `bearer`, un token truncado y el usuario `Administrador Desarrollo` con rol `ADMINISTRADOR` y sus permisos.

> Si aparece `RuntimeError` al arrancar, revise el paso 5.1 (`DB_USER`, `DB_PASSWORD` y `JWT_SECRET`). Si aparece un error `IM002` de `pyodbc`, falta el ODBC Driver 18.

---

## 6. Ejecución del frontend (Angular)

### 6.1 Instalar dependencias locales

```powershell
cd C:\SIGIH\Hospital_San_Gabriel\frontend
npm install
```

Esto descarga Angular 21, Bootstrap 5, Bootstrap Icons, RxJS, TypeScript, Vitest y el resto de dependencias en `frontend/node_modules/`. **Es obligatorio ejecutarlo antes del arranque** para garantizar la disponibilidad local (incluso sin conexión) de Bootstrap y las librerías.

- Si npm 10 falla con `Cannot read properties of null (reading 'edgesOut')`, use:

```powershell
npx --yes npm@11 install
```

- Alternativa reproducible con el lockfile: `npm ci` (o `npx --yes npm@11 ci`).

### 6.2 Arrancar el servidor de desarrollo

```powershell
cd C:\SIGIH\Hospital_San_Gabriel\frontend
npm start
```

`npm start` ejecuta `ng serve`, que:

- Compila la aplicación en modo desarrollo.
- Aplica `proxy.conf.json`, redirigiendo `/api` → `http://127.0.0.1:8000`.
- Publica la aplicación en **`http://localhost:4200`**.

Alternativas equivalentes:

```powershell
npx ng serve        # si no tiene Angular CLI global (no es necesario instalarlo)
ng serve            # solo si tiene @angular/cli global en el PATH
```

> No es necesario instalar Angular CLI de forma global: el proyecto usa la versión local de `node_modules`.

### 6.3 Comprobación del frontend

1. Abra <http://localhost:4200>. Debe aparecer la pantalla de inicio de sesión de SIGIH.
2. Verifique en la pestaña **Network** del navegador que las peticiones van a `/api/...` y responden `200`.
3. Si la compilación falla, revise la versión de Node (`node -v`) y vuelva a ejecutar `npm install`.

### 6.4 Compilación de producción (opcional)

```powershell
npm run build
```

Genera el bundle en `frontend/dist/frontend/`. Para la evaluación en laboratorio no es necesario: basta con `npm start`.

---

## 7. Verificación y acceso inicial

### 7.1 Credenciales sembradas por defecto

| Campo | Valor |
|---|---|
| Usuario | `admin.desarrollo@sigih.test` |
| Contraseña | `Admin.2026!` |
| Rol | `ADMINISTRADOR` (16 permisos) |

> Estas credenciales las crea `database/16_admin_inicial.sql`. **Cambie la contraseña después del primer inicio de sesión** desde el módulo **Usuarios → Cambiar contraseña**. El hash Argon2id vive en la base; la contraseña en claro no se almacena.

### 7.2 Checklist de conexión entre las 3 capas

Ejecute las comprobaciones en orden. No continúe a la siguiente capa si la anterior falla.

| # | Capa | Comprobación | Comando / acción | Resultado esperado |
|---|---|---|---|---|
| 1 | SQL Server | Servicio activo | `Get-Service *MSSQL*` | `Running` |
| 2 | SQL Server | Conexión | `sqlcmd -S .\SQLEXPRESS -E -C -Q "SELECT 1"` | Devuelve `1` |
| 3 | SQL Server | Base creada | `SELECT name FROM sys.databases WHERE name='SIGIH'` | Una fila: `SIGIH` |
| 4 | SQL Server | Modelo completo | Ejecutar `INSTALAR_SIGIH.sql` (incluye `99`) o `99_verificar.sql` | 11 tablas, 71 SPs, 3 roles, `sigih_app`, admin |
| 5 | Backend | Dependencias | `uv sync` | `Resolved ...` / `Installed ...` sin errores |
| 6 | Backend | Arranque | `uv run uvicorn src.backend.main:app` | `Uvicorn running on http://127.0.0.1:8000` |
| 7 | Backend | Swagger | Abrir `http://127.0.0.1:8000/docs` | Swagger UI con todos los routers |
| 8 | Backend | Login | `POST /api/auth/login` (paso 5.4) | `access_token` y `token_type: bearer` |
| 9 | Backend | Sesión | `GET /api/auth/me` con el token | Usuario y permisos |
| 10 | Frontend | Dependencias | `npm install` | Sin errores; existe `node_modules/` |
| 11 | Frontend | Arranque | `npm start` | `Local: http://localhost:4200/` |
| 12 | Frontend | Login visual | Abrir la URL e iniciar sesión | Dashboard con menú lateral completo |
| 13 | Integración | Datos reales | Crear una categoría y un producto | Aparecen en la tabla y en el dashboard |

### 7.3 Flujo funcional mínimo de aceptación

1. Inicie sesión con las credenciales del paso 7.1.
2. Confirme que el **dashboard** muestra los widgets de productos, alertas y valor estimado (con 0 productos en una base nueva).
3. Abra **Categorías → Nueva categoría**, cree una y verifique el toast de éxito.
4. Abra **Productos → Nuevo producto**, asígnelo a la categoría y guárdelo.
5. Registre una **entrada** en **Movimientos** (con lote y vencimiento si el producto los maneja).
6. Verifique que **Lotes**, **Alertas** y **Reportes** reflejan los datos.
7. Cierre sesión y vuelva a entrar para confirmar la persistencia.

Si los 7 pasos funcionan, las tres capas están correctamente conectadas.

---

## 8. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `uv : no se reconoce como nombre de un cmdlet` | `uv` no está en el PATH | Reinstale `uv` y abra una terminal nueva |
| `ModuleNotFoundError: No module named 'src'` | Comando ejecutado desde la raíz | `cd backend` antes de `uv run uvicorn src.backend.main:app` |
| `RuntimeError: Faltan DB_USER y DB_PASSWORD` | No existe `backend/.env` o está incompleto | Crear desde `.env.example` (paso 5.1) |
| `RuntimeError: JWT_SECRET falta en .env...` | Secreto ausente o de menos de 32 caracteres | Generar con `uv run python -c "import secrets; print(secrets.token_urlsafe(48))"` |
| `pyodbc.Error: ('IM002', ...)` | Falta el ODBC Driver 18 | Instalar el controlador (paso 2.6) |
| `Login failed for user 'sigih_app'` | `DB_PASSWORD` distinto del `APP_PASSWORD` del script 17 | Reejecutar `17_permisos_app.sql` con la misma clave y actualizar `.env` |
| Error `51801` al ejecutar el script 17 | Falta `APP_PASSWORD` o el modo SQLCMD | Ver paso 4.3 (SSMS) o usar `sqlcmd -v` (paso 4.4) |
| Acentos corruptos (`mǸdico`) en la base | Scripts leídos sin UTF-8 | Volver a ejecutar con `sqlcmd ... -f 65001` |
| `Cannot read properties of null (reading 'edgesOut')` | Bug de npm 10.9.3 con Vitest | `npx --yes npm@11 install` |
| `'ng' no se reconoce...` | Angular CLI no está global | Usar `npm start` o `npx ng serve` |
| `Port 4200 is already in use` | Otro proceso ocupa el puerto | `npx ng serve --port 4201` |
| `Port 8000 is already in use` | Otro backend/uvicorn activo | Cerrar el proceso anterior o cambiar el puerto (y ajustar el proxy) |
| El frontend carga pero las peticiones `/api` dan 404 | Backend detenido o se abrió el `dist` sin proxy | Iniciar el backend y usar `npm start` (no abrir el bundle directamente) |
| Error de CORS en el navegador | Se accedió sin el proxy de desarrollo | Usar `http://localhost:4200` con `npm start` |
| `Login` responde `401` | No se ejecutó `16_admin_inicial.sql` o credenciales incorrectas | Ejecutar el seed y revisar usuario/contraseña |
| La API arranca pero responde `500` al consultar | El usuario `sigih_app` no tiene `EXECUTE` o faltan SPs | Ejecutar `17_permisos_app.sql` y `99_verificar.sql` |

---

## 9. Anexos

### 9.1 Secuencia completa resumida

```powershell
# 1) Base de datos (desde la raíz del proyecto)
cd C:\SIGIH\Hospital_San_Gabriel

# Opción rápida: un solo archivo (incluye 00 a 17 y la verificación 99)
sqlcmd -S .\SQLEXPRESS -E -C -b -I -f 65001 -i database\INSTALAR_SIGIH.sql

# Opción detallada: ejecutar 00 a 17 en orden y luego 99
# sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\00_crear_base.sql
# ... ejecutar 01 a 16 en orden ...
# sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\17_permisos_app.sql -v APP_PASSWORD="Sigih.App.2026!"
# sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\99_verificar.sql

# 2) Backend (terminal 1)
cd C:\SIGIH\Hospital_San_Gabriel\backend
Copy-Item .env.example .env      # completar DB_PASSWORD y JWT_SECRET
uv sync
uv run uvicorn src.backend.main:app

# 3) Frontend (terminal 2)
cd C:\SIGIH\Hospital_San_Gabriel\frontend
npm install
npm start
```

### 9.2 Puertos y direcciones

| Servicio | Dirección | Puerto |
|---|---|---|
| SQL Server | `.\SQLEXPRESS` | Instancia con nombre (sin puerto explícito) |
| Backend FastAPI | `http://127.0.0.1:8000` | 8000 |
| Swagger UI | `http://127.0.0.1:8000/docs` | 8000 |
| Frontend Angular | `http://localhost:4200` | 4200 |

### 9.3 Variables de entorno del backend

| Variable | Obligatoria | Ejemplo | Descripción |
|---|---|---|---|
| `DB_SERVER` | Sí | `.\SQLEXPRESS` | Instancia de SQL Server |
| `DB_NAME` | Sí | `SIGIH` | Base de datos |
| `DB_DRIVER` | Sí | `ODBC Driver 18 for SQL Server` | Driver ODBC |
| `DB_USER` | Sí | `sigih_app` | Usuario de aplicación (solo EXECUTE) |
| `DB_PASSWORD` | Sí | `Sigih.App.2026!` | Debe coincidir con `APP_PASSWORD` del script 17 |
| `JWT_SECRET` | Sí | 64+ caracteres | Firma de tokens; mínimo 32 |
| `JWT_EXPIRACION_MINUTOS` | Sí | `60` | Vigencia del token |

### 9.4 Notas de seguridad

- `backend/.env` contiene credenciales y **no se versiona**; manténgalo fuera de cualquier copia pública.
- El usuario `sigih_app` solo puede ejecutar procedimientos del esquema `dbo`; no lea ni escriba tablas directamente.
- Cambie la contraseña del administrador tras la primera sesión.
- No ejecute la API con `--reload` en la entrega: el comando oficial es `uv run uvicorn src.backend.main:app`.
- Para un entorno productivo real, sirva el frontend compilado con un servidor web y use HTTPS; esta guía está pensada para evaluación local.

### 9.5 Referencias internas

- `database/README.md` — detalle de cada script y reglas de negocio (errores `409`, stock, auditoría).
- `frontend/README.md` — estructura del frontend, scripts y módulos del Paso 7.
- `backend/src/backend/main.py` — routers, CORS y manejo de errores HTTP.
