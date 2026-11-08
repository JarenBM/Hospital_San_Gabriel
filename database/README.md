# SIGIH - Scripts de base de datos

Scripts idempotentes para SQL Server 2017+ (probado en SQL Server 2025 Express).
Se pueden ejecutar varias veces: las tablas usan `IF OBJECT_ID(...) IS NULL` y
los procedimientos `CREATE OR ALTER`.

> Instalación completa del proyecto: [`../README.md`](../README.md#inicio-rápido-1015-minutos).

## Instalación rápida (un solo archivo)

Para un equipo nuevo **no hace falta ejecutar los 20 scripts uno por uno**. El
archivo **`INSTALAR_SIGIH.sql`** contiene todo el proceso en orden: creación de
la base, tablas, RBAC, stored procedures, catálogos, roles, administrador, login
`sigih_app`, datos de demostración y la verificación final.

**SSMS**

1. Conéctese a `.\SQLEXPRESS` con autenticación de Windows.
2. Abra `INSTALAR_SIGIH.sql` y pulse **F5**.
3. Revise la pestaña **Mensajes**: debe terminar con `INSTALACIÓN SIGIH FINALIZADA`
   y no mostrar errores en rojo.

**sqlcmd**

```powershell
cd <carpeta-del-proyecto>
sqlcmd -S .\SQLEXPRESS -E -C -b -I -f 65001 -i database\INSTALAR_SIGIH.sql
```

En PowerShell, reemplace `<carpeta-del-proyecto>` por la ruta real, por ejemplo
`C:\Users\SuUsuario\Documents\Hospital_San_Gabriel`.

> **Contraseña de `sigih_app`:** el archivo define
> `DECLARE @password NVARCHAR(128) = N'Sigih.App.2026!';`. Debe coincidir con
> `DB_PASSWORD` de `backend/.env`. Si la base ya existía, ejecutar el archivo
> cambia la contraseña del login: ajuste esa línea antes de ejecutarlo.
>
> El archivo es **idempotente**, no borra datos y ya incluye `99_verificar.sql`
> al final. Los scripts individuales se mantienen para mantenimiento y estudio.

## Orden de ejecución

```powershell
cd <carpeta-del-proyecto>

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
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\17_permisos_app.sql -v APP_PASSWORD="UnaClaveFuerte.2026!"
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\18_seed_demo.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\99_verificar.sql
```

`17_permisos_app.sql` exige `APP_PASSWORD`. Si se omite, el script falla con
el error `51801` en lugar de crear el usuario con una clave vacía.

> **Codificación:** `-f 65001` es obligatorio para que `sqlcmd` lea los
> archivos UTF-8 y no corrompa acentos (`médico`, `Hospitalización`).
>
> **DML manual:** si se ejecutan `INSERT/UPDATE/DELETE` directos sobre
> `dbo.Lotes`, usar además `-I` para activar `QUOTED_IDENTIFIER ON`; los
> índices filtrados de lotes lo exigen. El backend y los SP no tienen este
> problema porque fijan la opción al crearse.

## Credenciales iniciales

| Elemento | Valor |
|---|---|
| Usuario API (administrador) | `admin.desarrollo@sigih.test` |
| Contraseña API (administrador) | `Admin.2026!` |
| Rol | `ADMINISTRADOR` |
| Usuario API (almacén) | `almacen.demo@sigih.test` |
| Contraseña API (almacén) | `Admin.2026!` |
| Rol | `ALMACEN` |
| Usuario de aplicación SQL | `sigih_app` |
| Contraseña de `sigih_app` | `Sigih.App.2026!` (debe coincidir con `backend/.env`) |

> Cambiar la contraseña después del primer inicio de sesión. El hash Argon2id
> vive en `16_admin_inicial.sql`; no se guarda la contraseña en la base.

## Usuario de aplicación

`17_permisos_app.sql` crea el login `sigih_app` y le aplica:

- `GRANT EXECUTE ON SCHEMA::dbo`
- `DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo`

El backend se conecta con `sigih_app`, por lo que solo puede ejecutar `EXEC
sp_...`. El acceso directo a tablas queda bloqueado.

## Estructura

| Script | Contenido |
|---|---|
| `00` | Crea la base `SIGIH` |
| `01` | Tablas base e índices |
| `02` | Roles, permisos, asignaciones y auditoría |
| `03` | SPs de usuarios |
| `04` | SPs de roles y permisos |
| `05` | SPs de categorías |
| `06` | SPs de productos |
| `07` | SPs de lotes |
| `08` | SPs de movimientos (entradas/salidas) |
| `09` | SPs de áreas |
| `10` | Alertas y dashboard |
| `11` | Reportes |
| `12` | Auditoría (registro) |
| `13` | Wrappers con nombres legacy |
| `14` | Catálogos iniciales |
| `15` | Roles, permisos y asignaciones |
| `16` | Administrador inicial |
| `17` | Usuario `sigih_app` y permisos |
| `18` | Datos de demostración (catálogos, productos, lotes y movimientos) |
| `99` | Verificación |

## Reglas de negocio relevantes

- Desactivar un producto con existencias (`stock_actual > 0`) devuelve error
  `51009` y el backend responde `409`.
- Desactivar una categoría con productos activos devuelve `51404` y `409`.
- El último administrador activo no se puede desactivar (`52004`, `409`).
- Las entradas y salidas actualizan stock y movimiento en una sola transacción
  dentro del SP.
- `18_seed_demo.sql` tampoco escribe `Lotes.stock_actual` directamente: usa los
  SP de entrada y salida, así que el stock y el kardex siempre cuadran. Sus
  movimientos se reparten en los últimos cuatro meses.
- La auditoría es best-effort: un fallo al registrarla nunca revierte la
  operación principal.

## Notas

- `13_wrappers_legacy.sql` mantiene los nombres antiguos (20 wrappers;
  `sp_Dashboard_Resumen` ya era canónico). Se puede retirar cuando ya no
  queden clientes con esos nombres.
- `sp_Alertas_PorVencer` devuelve tanto `PROXIMO` como `VENCIDO` para conservar
  la compatibilidad con `sp_Lote_Vencimientos`; el backend filtra por estado.
- La paginación se difiere a la Fase 3 del frontend.
