# SIGIH · Sistema de Gestión de Inventario Hospitalario

Sistema web de inventario para el **Hospital San Gabriel**: productos, lotes,
movimientos de entrada y salida, áreas hospitalarias, alertas de stock y
vencimiento, reportes y administración de usuarios con roles y permisos.

| Capa | Tecnología | Carpeta |
|---|---|---|
| Base de datos | SQL Server (Express o Developer) | `database/` |
| API | Python 3.14 + FastAPI + uvicorn | `backend/` |
| Interfaz web | Angular 22 + Bootstrap 5 | `frontend/` |

Las tres capas corren en la misma máquina. La API escucha en `127.0.0.1:8000` y
la interfaz en `localhost:4200`, que redirige `/api` a la API mediante
`frontend/proxy.conf.json`.

> **Guía detallada:** [`MANUAL_DESPLIEGUE.md`](MANUAL_DESPLIEGUE.md) explica
> cada paso, la instalación de requisitos y la solución de problemas.

---

## Requisitos

| Componente | Versión mínima | Cómo verificar |
|---|---|---|
| Node.js | `^22.22.3`, `^24.15.0` o `>=26.0.0` | `node -v` |
| npm | 10.9.9 o superior | `npm -v` |
| Python | 3.14 (el proyecto lo fija) | `python --version` |
| uv | Última estable | `uv --version` |
| SQL Server | Express o Developer, activo | `Get-Service *MSSQL*` |
| ODBC Driver 18 | `ODBC Driver 18 for SQL Server` | `Get-OdbcDriver` |
| `sqlcmd` o SSMS | Para ejecutar los scripts SQL | `sqlcmd -?` |

> **Angular 22 exige Node 22.22.3 o superior.** Con una versión anterior,
> `npm start` falla con `The Angular CLI requires a minimum Node.js version`.
> El proyecto se validó con **Node 22.23.4**; cualquier versión dentro del rango
> admitido funciona.

Instalación rápida de lo que falte (Windows + winget):

```powershell
winget install OpenJS.NodeJS.LTS
winget install astral-sh.uv
winget install Microsoft.SQLServer.2022.Express
winget install Microsoft.SQLServerManagementStudio
```

El **ODBC Driver 18** se descarga aparte:
<https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server>

> SQL Server Express requiere elegir la instancia **`SQLEXPRESS`** y habilitar
> la autenticación de Windows durante la instalación. El detalle está en la
> sección 2.4 del [manual](MANUAL_DESPLIEGUE.md#24-sql-server).

---

## Inicio rápido (10–15 minutos)

Ejecute los pasos **en orden**. Cada uno indica qué debe ver antes de continuar.

### 1. Abrir PowerShell en la carpeta del proyecto

```powershell
cd C:\ruta\donde\clonaste\Hospital_San_Gabriel
```

Ajuste la ruta a la suya. Todos los comandos se ejecutan desde aquí salvo que se
indique otra carpeta.

### 2. Crear la base de datos

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -b -I -f 65001 -i database\INSTALAR_SIGIH.sql
```

**Resultado esperado:** la última línea dice `INSTALACIÓN SIGIH FINALIZADA` y no
hay mensajes en rojo.

Esto crea la base `SIGIH`, sus 11 tablas, 71 procedimientos almacenados, los 3
roles, el usuario administrador y el login de aplicación `sigih_app`. Además
carga **datos de demostración**: 5 categorías, 8 áreas, 21 productos, 23 lotes y
43 movimientos, con alertas de stock bajo y vencimientos.

> Si no tiene `sqlcmd`, abra `database\INSTALAR_SIGIH.sql` en SSMS y pulse `F5`.

### 3. Instalar dependencias del backend

```powershell
cd backend
uv sync
```

**Resultado esperado:** `Resolved ...` y `Installed ...` sin errores. Se crea
`backend\.venv`.

> El archivo `backend\.env` **ya viene incluido** con las credenciales de
> desarrollo. No necesita crearlo ni editarlo.

### 4. Arrancar el backend (terminal 1)

```powershell
uv run uvicorn src.backend.main:app
```

**Resultado esperado:**

```text
Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

Deje esta terminal abierta. Compruebe <http://127.0.0.1:8000/docs>.

### 5. Instalar y arrancar el frontend (terminal 2)

Abra **otra** terminal en la carpeta del proyecto y ejecute:

```powershell
cd frontend
npm install
npm start
```

**Resultado esperado:** compilación correcta y el mensaje
`Local: http://localhost:4200/`.

### 6. Entrar al sistema

Abra <http://localhost:4200> e inicie sesión:

| Campo | Valor |
|---|---|
| Correo | `admin.desarrollo@sigih.test` |
| Contraseña | `Admin.2026!` |

Debe ver el dashboard con el menú lateral completo.

---

## Credenciales de desarrollo

| Uso | Usuario | Contraseña |
|---|---|---|
| Aplicación web (administrador) | `admin.desarrollo@sigih.test` | `Admin.2026!` |
| Aplicación web (almacén) | `almacen.demo@sigih.test` | `Admin.2026!` |
| Login de SQL Server (solo API) | `sigih_app` | `Sigih.App.2026!` |

- El usuario `sigih_app` **solo puede ejecutar procedimientos**; no lee ni
  escribe tablas directamente.
- Cambie la contraseña del administrador después del primer inicio de sesión
  (módulo **Usuarios**).

---

## Puertos y direcciones

| Servicio | Dirección |
|---|---|
| Frontend | <http://localhost:4200> |
| API | <http://127.0.0.1:8000> |
| Swagger UI | <http://127.0.0.1:8000/docs> |
| SQL Server | `.\SQLEXPRESS` (instancia con nombre) |

---

## Problemas comunes

| Síntoma | Solución |
|---|---|
| `The Angular CLI requires a minimum Node.js version` | Actualice Node a 22.22.3+ y abra una terminal nueva |
| `npm start` falla con `edgesOut` | Actualice npm: `npm install -g npm@11` |
| `'uv' no se reconoce` | Instale uv y abra una terminal nueva |
| `ModuleNotFoundError: No module named 'src'` | Ejecute el backend **desde `backend/`** |
| `pyodbc.Error: ('IM002', ...)` | Falta el ODBC Driver 18 |
| `Login failed for user 'sigih_app'` | `DB_PASSWORD` no coincide con la del instalador SQL |
| El frontend responde `404` en `/api/...` | El backend no está arrancado |
| `Port 4200 is already in use` | `npm start -- --port 4201` |

Tabla completa en
[`MANUAL_DESPLIEGUE.md`](MANUAL_DESPLIEGUE.md#8-problemas-comunes).

---

## Documentación

| Documento | Contenido |
|---|---|
| [`MANUAL_DESPLIEGUE.md`](MANUAL_DESPLIEGUE.md) | Instalación desde cero, verificación y solución de problemas |
| [`database/README.md`](database/README.md) | Scripts SQL, orden de ejecución y reglas de negocio |
| [`backend/README.md`](backend/README.md) | Configuración y arranque de la API |
| [`frontend/README.md`](frontend/README.md) | Estructura del frontend y capa de datos |

---

## Nota sobre `backend/.env`

Este repositorio es un **proyecto académico**. Incluye `backend/.env` con
credenciales de desarrollo para que, al clonar, el sistema funcione sin
configuración adicional.

- Esos valores son **solo para uso local**.
- Si el proyecto se despliega en un entorno real, genere un `JWT_SECRET` nuevo
  y cambie la contraseña de `sigih_app`:

  ```powershell
  uv run python -c "import secrets; print(secrets.token_urlsafe(48))"
  ```

- El archivo `.env.example` se mantiene como plantilla de referencia.
