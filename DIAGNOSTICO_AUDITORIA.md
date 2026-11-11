# Diagnóstico de auditoría — SIGIH

**Fecha:** 10 de noviembre de 2026  
**Rama:** `rediseno_visual`  
**Alcance:** backend FastAPI, base SQL Server `SIGIH` y frontend Angular.  
**Estado general:** P1–P4 implementados, aplicados y verificados. P5 queda diferido como deuda técnica.

## Resumen

| ID | Hallazgo | Prioridad | Estado |
|---|---|---|---|
| P1 | Clasificación de errores SQL por coincidencia de subcadenas | Alta | Corregido |
| P2 | Listados sin paginación y filtrado en el cliente | Alta | Corregido |
| P3 | Motivos de entrada duplicados entre backend y frontend | Media | Corregido |
| P4 | Wrappers legacy y `sp_Productos_Reactivar` sin uso | Media | Corregido |
| P5 | Migración a Signal Forms | Baja | Diferido |

---

## P1 — Clasificación de errores SQL

### Hallazgo

`repositories/errores_sql.py` comparaba los códigos de error con una búsqueda de subcadenas sobre el texto de la excepción. Códigos cortos como `547` podían aparecer dentro de una fecha, una cantidad o un identificador, y provocaban que una operación válida se clasificara como `datos_invalidos` (HTTP 422). Además, el orden de comparación no era explícito y dificultaba añadir códigos nuevos.

### Corrección aplicada

- Se extraen los códigos de proyecto con la expresión regular `\((\d{4,5})\)` (los `THROW` usan `51xxx`/`52xxx`), de modo que no se confunden con números sueltos de fechas, cantidades o identificadores.
- Los errores estándar de 3 dígitos, como `547`, se cubren con el respaldo SQLSTATE `23000` en lugar de buscarse como subcadena.
- Los códigos esperados se guardan en `frozenset` y se comparan por intersección, no por subcadena.
- Se conserva el orden de prioridad de `_TIPOS` (duplicado, no encontrado, conflicto, datos inválidos, inventario).
- Se añadió un respaldo por SQLSTATE `23000` para violaciones de integridad cuando el mensaje no trae el número.
- El helper `_extraer_codigos()` concentra la extracción y facilita las pruebas.

### Rutas y líneas

| Archivo | Línea | Contenido |
|---|---|---|
| `backend/src/backend/repositories/errores_sql.py` | 9 | `_TIPOS` con `frozenset` |
| `backend/src/backend/repositories/errores_sql.py` | 43 | `_PATRON_CODIGO = re.compile(r"\((\d{4,5})\)")` |
| `backend/src/backend/repositories/errores_sql.py` | 47 | Respaldo SQLSTATE `23000` |
| `backend/src/backend/repositories/errores_sql.py` | 50 | `_extraer_codigos()` |
| `backend/src/backend/repositories/errores_sql.py` | 63 | `clasificar()` |

### Verificación

```text
clasificar(Error("23000", "... (2627) ...")) -> duplicado
clasificar(Error("42000", "... (52004)"))    -> ultimo_admin
```

No se modificó la API pública de `clasificar()` ni la traducción a excepciones de dominio de cada repository.

### Pendiente recomendado

Añadir pruebas unitarias de `clasificar()` cuando se incorpore `pytest` al backend. Hoy no hay runner de pruebas instalado.

---

## P2 — Paginación de listados

### Hallazgo

Los endpoints de productos, usuarios y movimientos devolvían la tabla completa. El frontend descargaba todo y aplicaba búsqueda, estado, categoría, rol, área y fechas en memoria. Con 25 productos y 51 movimientos no se notaba, pero el coste crece de forma lineal con el histórico y el filtrado local no podía aprovechar índices.

### Corrección aplicada

#### SQL

Los tres SP de listado aceptan `@pagina` y `@tamano`, ambos opcionales:

- Si no se envían, se usa `OFFSET 0` y `FETCH NEXT 2147483647`, por lo que el comportamiento anterior se conserva.
- Si se envían, se normalizan a página ≥ 1 y tamaño ≥ 1 (25 por defecto).
- Cada fila incluye `COUNT(*) OVER () AS total`, calculado antes de aplicar `OFFSET/FETCH`.
- `sp_Movimientos_Listar` añade `@busqueda` para buscar en código, producto, lote, motivo y usuario.

| Archivo | Línea | Contenido |
|---|---|---|
| `database/03_sp_usuarios.sql` | 70–91 | Firma y cálculo de offset |
| `database/03_sp_usuarios.sql` | 109 | `COUNT(*) OVER () AS total` |
| `database/03_sp_usuarios.sql` | 123 | `OFFSET/FETCH` |
| `database/06_sp_productos.sql` | 12–33 | Firma y cálculo de offset |
| `database/06_sp_productos.sql` | 51 | `COUNT(*) OVER () AS total` |
| `database/06_sp_productos.sql` | 71 | `OFFSET/FETCH` |
| `database/08_sp_movimientos.sql` | 236–262 | Firma, `@busqueda` y offset |
| `database/08_sp_movimientos.sql` | 277 | `COUNT(*) OVER () AS total` |
| `database/08_sp_movimientos.sql` | 289–294 | Filtro `@busqueda` |
| `database/08_sp_movimientos.sql` | 296 | `OFFSET/FETCH` |

#### Backend

- Repositories, services y APIs aceptan `pagina` y `tamano` opcionales.
- Los services devuelven `(filas, total)`; `repositories/base.total_de()` lee la columna `total`.
- Las APIs añaden `X-Total-Count` en todas las respuestas de listado, también cuando no se pagina.
- `GET /api/movimientos` acepta además `busqueda`.

| Archivo | Línea | Contenido |
|---|---|---|
| `backend/src/backend/repositories/base.py` | 92 | `total_de()` |
| `backend/src/backend/repositories/producto_repository.py` | 40 | `listar_productos(..., pagina, tamano)` |
| `backend/src/backend/repositories/movimiento_repository.py` | 99 | `listar_movimientos(..., busqueda, pagina, tamano)` |
| `backend/src/backend/repositories/usuario_repository.py` | 61 | `listar_usuarios(..., pagina, tamano)` |
| `backend/src/backend/services/producto_service.py` | 21 | Devuelve `(lista, total)` |
| `backend/src/backend/services/movimiento_service.py` | 21 | Devuelve `(lista, total)` |
| `backend/src/backend/services/usuario_service.py` | 27 | Devuelve `(lista, total)` |
| `backend/src/backend/apis/producto_api.py` | 29–47 | Query params y cabecera |
| `backend/src/backend/apis/movimiento_api.py` | 41–68 | Query params y cabecera |
| `backend/src/backend/apis/usuario_api.py` | 35–54 | Query params y cabecera |

#### Frontend

- `Paginacion` centraliza `pagina` y `tamano`; los filtros de producto, usuario y movimiento lo extienden.
- `Recurso.total` expone el total leído de `X-Total-Count`.
- `ApiService.cargarPaginadoEn()` procesa la respuesta completa (`observe: 'response'`).
- `productosPagina` es un recurso separado del catálogo completo `productos`; así lotes, reportes y selectores siguen recibiendo todos los productos activos.
- `usuarios` y `movimientos` pasan a paginarse porque solo los consume su propia vista.
- El componente reutilizable `Paginador` muestra rango, página y total, y emite el cambio de página.
- Búsqueda, estado, categoría, rol, área y fechas reinician a la página 1 y consultan al servidor. La búsqueda de texto usa un debounce de 300 ms.

| Archivo | Línea | Contenido |
|---|---|---|
| `frontend/src/app/models/api.models.ts` | 51 | `interface Paginacion` |
| `frontend/src/app/core/services/api.service.ts` | 71 | `Recurso.total` |
| `frontend/src/app/core/services/api.service.ts` | 151 | `productosPagina` |
| `frontend/src/app/core/services/api.service.ts` | 300 | `cargarUsuarios()` paginado |
| `frontend/src/app/core/services/api.service.ts` | 538 | `cargarProductosPagina()` |
| `frontend/src/app/core/services/api.service.ts` | 612 | `cargarMovimientos()` paginado |
| `frontend/src/app/core/services/api.service.ts` | 763 | `cargarPaginadoEn()` |
| `frontend/src/app/shared/components/paginador/paginador.ts` | 23 | Componente `Paginador` |
| `frontend/src/app/features/productos/productos.ts` | 56 | Usa `productosPagina` |
| `frontend/src/app/features/productos/productos.ts` | 486 | `filtrosServidor()` |
| `frontend/src/app/features/movimientos/movimientos.ts` | 607 | `filtrosServidor()` |
| `frontend/src/app/features/usuarios/usuarios.ts` | 511 | `recargarUsuarios()` |
| `frontend/src/app/features/productos/productos.html` | 245 | `<app-paginador>` |
| `frontend/src/app/features/movimientos/movimientos.html` | 244 | `<app-paginador>` |
| `frontend/src/app/features/usuarios/usuarios.html` | 204 | `<app-paginador>` |

### Compatibilidad

- Sin `pagina`/`tamano`, los endpoints devuelven todos los resultados.
- Los schemas Pydantic ignoran la columna extra `total`; el JSON de cada fila no cambia.
- El catálogo completo `ApiService.productos` sigue existiendo para `productosActivos`, lotes y reportes.

### Verificación

Ejecución directa de los SP contra `SIGIH`:

```text
Productos:  25 filas totales; página de 3 devuelve 3 con total=25.
Usuarios:    4 filas totales; página de 2 devuelve 2 con total=4.
Movimientos: 51 filas; búsqueda "Paracetamol" devuelve 4, página de 2 devuelve 2.
```

Prueba HTTP end-to-end con el administrador demo:

```text
GET /api/productos?pagina=1&tamano=5              -> 5 filas, X-Total-Count: 25
GET /api/movimientos?pagina=1&tamano=2&busqueda=... -> 2 filas, X-Total-Count: 4
GET /api/usuarios?pagina=1&tamano=2               -> 2 filas, X-Total-Count: 4
```

### Limitación conocida

`COUNT(*) OVER ()` no produce filas si la página solicitada queda fuera de rango; en ese caso `X-Total-Count` vale `0`. El frontend reinicia a la página 1 al cambiar filtros y acota la navegación con `totalPaginas`, por lo que el caso solo aparece si otra sesión reduce el conjunto mientras se está en la última página. Queda documentado como mejora futura (devolver el total en un segundo result set o en una consulta aparte).

### Despliegue

En una base existente hay que ejecutar, en este orden:

```powershell
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\03_sp_usuarios.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\06_sp_productos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\08_sp_movimientos.sql
sqlcmd -S .\SQLEXPRESS -E -C -b -f 65001 -i database\19_eliminar_wrappers_legacy.sql
```

Sin esos scripts, el backend nuevo enviaría `@pagina`/`@tamano` a SP antiguos y SQL Server rechazaría la llamada.

---

## P3 — Catálogo único de motivos de entrada

### Hallazgo

El backend validaba los motivos con el enum Pydantic `MotivoEntrada`, pero el frontend mantenía una constante `MOTIVOS_ENTRADA` con los mismos valores. Cualquier cambio en el enum obligaba a editar dos sitios y podía dejar el selector mostrando opciones que la API rechazaba.

### Corrección aplicada

- El enum `MotivoEntrada` sigue siendo la única fuente de verdad.
- Se expone `GET /api/movimientos/motivos-entrada`, protegido con `movimientos:leer`, que devuelve `["Compra", "Donación", "Devolución"]`.
- El frontend carga el catálogo al iniciar la vista de movimientos y usa la constante local solo como respaldo si la petición falla.
- La validación del formulario usa el catálogo cargado.

| Archivo | Línea | Contenido |
|---|---|---|
| `backend/src/backend/schemas/movimiento.py` | 15 | Enum `MotivoEntrada` |
| `backend/src/backend/apis/movimiento_api.py` | 31–38 | Endpoint `motivos-entrada` |
| `frontend/src/app/core/services/api.service.ts` | 638 | `cargarMotivosEntrada()` |
| `frontend/src/app/features/movimientos/movimientos.ts` | 582 | Carga del catálogo |
| `frontend/src/app/features/movimientos/movimientos.html` | 347 | Selector alimentado por la señal |

### Verificación

```text
GET /api/movimientos/motivos-entrada -> ["Compra", "Donación", "Devolución"]
```

---

## P4 — Limpieza de wrappers legacy y código muerto

### Hallazgo

`database/13_wrappers_legacy.sql` mantenía 20 procedimientos con los nombres antiguos que delegaban en los canónicos. Ningún script ni repositorio los ejecutaba ya. Además, `sp_Productos_Reactivar` existía en la base y en el catálogo Python, pero no había endpoint ni flujo de reactivación de productos.

### Corrección aplicada

- Se creó `database/19_eliminar_wrappers_legacy.sql` con `DROP PROCEDURE IF EXISTS` para los 20 wrappers y para `sp_Productos_Reactivar`.
- Se eliminó `database/13_wrappers_legacy.sql`.
- `database/INSTALAR_SIGIH.sql` ya no crea wrappers ni `sp_Productos_Reactivar`; incluye el bloque 19 después de los seeds.
- `database/99_verificar.sql` y la copia embebida en `INSTALAR_SIGIH.sql` ya no esperan `sp_Productos_Reactivar`.
- Se retiró `PRODUCTOS_REACTIVAR` del catálogo `procedimientos.py`.
- Se actualizaron docstrings de schemas que citaban nombres legacy.
- Se actualizaron `database/README.md`, `MANUAL_DESPLIEGUE.md` y `backend/AGENTS.md`.

### Wrappers eliminados

`sp_Usuario_Crear`, `sp_Usuario_ObtenerPorEmail`, `sp_Categoria_Crear`, `sp_Categoria_Listar`, `sp_Categoria_Obtener`, `sp_Categoria_Actualizar`, `sp_Categoria_Desactivar`, `sp_Producto_Crear`, `sp_Producto_Listar`, `sp_Producto_Obtener`, `sp_Producto_Actualizar`, `sp_Producto_Desactivar`, `sp_Lote_ListarPorProducto`, `sp_Entrada_Registrar`, `sp_Salida_Registrar`, `sp_Movimiento_Listar`, `sp_Producto_StockBajo`, `sp_Lote_Vencimientos`, `sp_Producto_MayoresSalidas` y `sp_Area_Listar`.

### Rutas y líneas

| Archivo | Línea | Contenido |
|---|---|---|
| `database/19_eliminar_wrappers_legacy.sql` | 1–35 | Script idempotente de retirada |
| `database/INSTALAR_SIGIH.sql` | 2800–2841 | Bloque 19 embebido |
| `database/06_sp_productos.sql` | 214–218 | Fin del archivo, sin `sp_Productos_Reactivar` |
| `backend/src/backend/repositories/procedimientos.py` | 45–50 | Catálogo sin `PRODUCTOS_REACTIVAR` |
| `database/99_verificar.sql` | 32 | Verificación sin `sp_Productos_Reactivar` |

### Verificación

```text
SELECT COUNT(*) FROM sys.procedures
WHERE name IN ('sp_Usuario_Crear', 'sp_Producto_Listar',
               'sp_Entrada_Registrar', 'sp_Area_Listar',
               'sp_Productos_Reactivar');
-- Resultado: 0
```

El backend sigue usando exclusivamente los SP canónicos en plural (`sp_Usuarios_*`, `sp_Categorias_*`, `sp_Productos_*`, `sp_Lotes_*`, `sp_Movimientos_*`, `sp_Areas_*`).

### Impacto

Cualquier cliente externo que todavía llamara a los nombres legacy dejará de funcionar. El repositorio no contiene ninguno y el backend ya usaba los canónicos, por lo que el cambio es seguro dentro del proyecto.

---

## P5 — Signal Forms (diferido)

### Situación

Angular 22 ofrece el módulo experimental de Signal Forms, pero las vistas actuales usan `@angular/forms` con signals propios para el estado y validaciones manuales equivalentes a Pydantic. La migración no aporta una corrección funcional y afecta a varios formularios grandes (productos, usuarios, movimientos, áreas, categorías, roles y login).

### Motivo del diferimiento

- Es una migración transversal, no un defecto de la auditoría.
- Mezclar Signal Forms y formularios actuales en la misma vista aumentaría el riesgo.
- Requiere pruebas de regresión de validaciones, estados de guardado y mensajes de error.

### Plan propuesto

1. Fijar la versión estable de Signal Forms y revisar su API (`form()`, `field()`, validadores).
2. Migrar primero un formulario pequeño y aislado (login o categorías).
3. Comparar comportamiento y mensajes de error con el formulario actual.
4. Migrar el resto por vista, sin mezclar patrones.
5. Añadir pruebas de componente antes de retirar las validaciones manuales.

No se tocó ningún formulario en esta fase.

---

## Validaciones ejecutadas

| Validación | Resultado |
|---|---|
| `npm run build` | Correcto; bundle inicial 717.86 kB |
| `npm test -- --watch=false` | 4 archivos, 9 pruebas aprobadas |
| `uv run python -m compileall -q src` | Correcto |
| Importación de `backend.main` | Correcta; 33 rutas OpenAPI |
| Aplicación de scripts 03/06/08/19 en `SIGIH` | Correcta |
| Totales de paginación vía `sqlcmd` | Productos 25, usuarios 4, movimientos 51 |
| Búsqueda de movimientos `Paracetamol` | 4 coincidencias |
| Prueba HTTP con login demo | Cabeceras `X-Total-Count` correctas |
| Endpoint de motivos | `Compra`, `Donación`, `Devolución` |

## Riesgos residuales

- El backend no tiene runner de pruebas instalado; P1 y los services se validaron manualmente.
- El SQL no está cubierto por CI; los scripts se probaron contra `SIGIH` local.
- Las pruebas del frontend no cubren todavía el componente `Paginador` ni los estados vacíos paginados.
- La página fuera de rango devuelve `total=0` (ver limitación en P2).
- No se hizo commit ni push: todos los cambios quedan en el árbol de trabajo de `rediseno_visual`.
