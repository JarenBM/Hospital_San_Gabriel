# SIGIH · Backend (FastAPI)

API REST del **Sistema de Gestión de Inventario Hospitalario**. Expone los
módulos de autenticación, usuarios, roles, categorías, productos, lotes,
movimientos, áreas, alertas, dashboard y reportes.

Se conecta a SQL Server mediante `pyodbc` y **solo ejecuta procedimientos
almacenados**: el usuario `sigih_app` no tiene permisos directos sobre las
tablas.

## Requisitos

| Componente | Versión |
|---|---|
| Python | 3.14 (lo fija `.python-version`) |
| uv | Última estable |
| SQL Server | Express o Developer, con la base `SIGIH` instalada |
| ODBC Driver 18 | `ODBC Driver 18 for SQL Server` |

## Configuración

El archivo **`.env` ya viene incluido** en el repositorio con credenciales de
desarrollo:

```dotenv
DB_SERVER=.\SQLEXPRESS
DB_NAME=SIGIH
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_USER=sigih_app
DB_PASSWORD=Sigih.App.2026!
JWT_SECRET=<64 caracteres>
JWT_EXPIRACION_MINUTOS=60
```

Solo necesita editarlo si su instancia de SQL Server no es `.\SQLEXPRESS`, si
cambió la contraseña de `sigih_app` o si va a desplegar en producción.

| Variable | Obligatoria | Descripción |
|---|---|---|
| `DB_SERVER` | Sí | Instancia de SQL Server |
| `DB_NAME` | Sí | Base de datos (`SIGIH`) |
| `DB_DRIVER` | Sí | Driver ODBC |
| `DB_USER` | Sí | Usuario de aplicación (solo EXECUTE) |
| `DB_PASSWORD` | Sí | Debe coincidir con el instalador SQL |
| `JWT_SECRET` | Sí | Firma de tokens; mínimo 32 caracteres |
| `JWT_EXPIRACION_MINUTOS` | Sí | Vigencia del token |

Para generar un secreto nuevo:

```powershell
uv run python -c "import secrets; print(secrets.token_urlsafe(48))"
```

## Instalación y arranque

```powershell
cd backend
uv sync
uv run uvicorn src.backend.main:app
```

**Resultado esperado:** `Uvicorn running on http://127.0.0.1:8000`.

> El comando debe ejecutarse **dentro de `backend/`**: desde la raíz del
> repositorio el módulo `src` no es importable.

## Verificación

1. Swagger UI: <http://127.0.0.1:8000/docs>
2. Login:

```powershell
$login = Invoke-RestMethod -Method Post `
  -Uri 'http://127.0.0.1:8000/api/auth/login' `
  -ContentType 'application/x-www-form-urlencoded' `
  -Body @{ username = 'admin.desarrollo@sigih.test'; password = 'Admin.2026!' }

$login.token_type
```

3. Sesión:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/auth/me' `
  -Headers @{ Authorization = "Bearer $($login.access_token)" }
```

## Estructura

```text
backend/
├── .env                  # configuración de desarrollo (versionada)
├── .env.example          # plantilla de referencia
├── .python-version       # 3.14
├── pyproject.toml
├── uv.lock
└── src/backend/
    ├── main.py           # app, routers y CORS
    ├── config.py         # lectura y validación de variables de entorno
    ├── database.py       # conexión pyodbc
    ├── dependencies.py   # dependencias de autenticación y permisos
    ├── security.py       # JWT y hash Argon2id
    ├── errors.py         # manejo uniforme de errores
    ├── apis/             # routers por módulo
    ├── services/         # reglas de negocio
    ├── repositories/     # llamadas a stored procedures
    └── schemas/          # modelos Pydantic
```

## Problemas comunes

| Síntoma | Solución |
|---|---|
| `ModuleNotFoundError: No module named 'src'` | Ejecutar desde `backend/` |
| `RuntimeError: Faltan DB_USER y DB_PASSWORD` | Restaurar `.env` |
| `RuntimeError: JWT_SECRET ...` | Generar un secreto de 32+ caracteres |
| `pyodbc.Error: ('IM002', ...)` | Instalar el ODBC Driver 18 |
| `Login failed for user 'sigih_app'` | `DB_PASSWORD` distinto al del instalador |
| `500` al consultar | Reejecutar `database/INSTALAR_SIGIH.sql` |

## Documentación

- [`../README.md`](../README.md) — inicio rápido del proyecto.
- [`../MANUAL_DESPLIEGUE.md`](../MANUAL_DESPLIEGUE.md) — instalación completa.
- [`../database/README.md`](../database/README.md) — scripts y reglas de negocio.
