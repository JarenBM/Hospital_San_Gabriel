# Reporte de Pruebas de Negocio — SIGIH

**Fecha:** 2026-11-11
**Rama:** `rediseno_visual`
**Alcance:** 10 módulos (autenticación/RBAC, catálogos, productos, lotes, movimientos, alertas, dashboard, kardex, auditoría, usuarios/roles).
**Método:** revisión estática de Backend (FastAPI), Frontend (Angular) y scripts SQL, más pruebas ejecutadas contra la base `SIGIH` real (`.\SQLEXPRESS`) dentro de transacciones con `ROLLBACK`.

---

## 1. Matriz de Verificación

| Módulo | Requerimiento / Regla | Estado | Archivo Afectado |
|---|---|---|---|
| Autenticación | Hash de contraseñas con Argon2id | APROBADO¹ | `backend/security.py`, `database/03_sp_usuarios.sql` |
| Autenticación | Firma y expiración del JWT (HS256, secreto ≥ 32) | APROBADO | `backend/config.py`, `backend/security.py` |
| RBAC | `requiere_permiso` reconsulta usuario y permisos en cada petición | APROBADO | `backend/dependencies.py` |
| RBAC | Guards Angular e interceptor `Bearer` | APROBADO | `frontend/.../auth.guard.ts`, `role.guard.ts`, `auth.interceptor.ts` |
| RBAC | Ocultamiento dinámico del menú según permisos | APROBADO | `frontend/.../shell.ts`, `navegacion.ts` |
| Catálogos | Nombres duplicados de categorías/áreas (case-insensitive) | APROBADO | `database/01_tablas_base.sql`, `05`, `09` |
| Catálogos | Eliminación lógica (`activo = 0`) | APROBADO | `database/05_sp_categorias.sql`, `09_sp_areas.sql` |
| Catálogos | Bloqueo de borrado de categoría con productos activos | APROBADO | `database/05_sp_categorias.sql` (51404 → 409) |
| Catálogos | Bloqueo de borrado de área con referencias activas | APROBADO (corregido) | `database/09_sp_areas.sql` (51504 → 409) |
| Productos | Unicidad de SKU/código | APROBADO | `database/01_tablas_base.sql`, `06_sp_productos.sql` |
| Productos | `stock_minimo >= 0` (Pydantic + SP + CHECK) | APROBADO | `backend/schemas/producto.py`, `database/06` |
| Productos | Bloqueo de edición directa del stock global | APROBADO (corregido) | `backend/schemas/producto.py` (`extra="forbid"`) |
| Lotes | Creación automática de lote en ENTRADAS (código + vencimiento) | APROBADO | `database/08_sp_movimientos.sql` |
| Movimientos | Stock insuficiente devuelve 409 | APROBADO | `database/08_sp_movimientos.sql` (51209/51210) |
| Movimientos | FEFO automático en salidas (lote más próximo) | APROBADO (corregido) | `database/08_sp_movimientos.sql`, `frontend/.../movimientos.*` |
| Lotes | Bloqueo de lotes vencidos (`fecha <= hoy`) | APROBADO (corregido) | `database/08`, `07`, `10`, `movimientos.ts` |
| Alertas | Stock bajo: `stock_disponible <= stock_minimo` | APROBADO | `database/10_sp_alertas_dashboard.sql` |
| Alertas | Por vencer: 1 a 30 días desde mañana | APROBADO (corregido) | `database/10_sp_alertas_dashboard.sql` |
| Alertas | Vencidos: `fecha_vencimiento <= hoy` | APROBADO (corregido) | `database/10_sp_alertas_dashboard.sql`, `07_sp_lotes.sql` |
| Dashboard | Recálculo en vivo de valor, productos y alertas | APROBADO² | `database/10_sp_alertas_dashboard.sql`, `api.service.ts` |
| Kardex | Balance `Saldo Inicial + Entradas − Salidas = Saldo Final` | APROBADO | `database/08_sp_movimientos.sql`, `reportes.ts` |
| Auditoría | Fecha, usuario, acción y área por cada movimiento | APROBADO (corregido) | `database/08_sp_movimientos.sql`, `02`, `12` |
| Auditoría | Cero SQL embebido en Python | APROBADO | `backend/repositories/base.py`, `procedimientos.py` |
| Usuarios | CRUD y asignación de roles | APROBADO | `database/03`, `04`, `frontend/.../usuarios.ts` |
| Usuarios | Protección de la cuenta semilla | APROBADO (corregido) | `database/03_sp_usuarios.sql` (52005 → 409) |
| Usuarios | Permisos dinámicos sin reiniciar el servidor | APROBADO backend / INCOMPLETO frontend³ | `backend/dependencies.py`, `frontend/.../auth.service.ts` |

¹ El hash lo verifica Argon2id en Python (`security.py`) usando el hash que entrega `sp_Usuarios_ObtenerSesion`; no existe `sp_usuarios_login`. El control es equivalente y el hash nunca sale al cliente.
² `sp_Dashboard_Resumen` calcula en vivo y el frontend recarga los recursos ya cargados tras un movimiento. Si el dashboard nunca se abrió, se calcula al entrar.
³ El backend aplica los cambios de permisos de inmediato (reconsulta por petición); el menú del frontend se actualiza al recargar o volver a iniciar sesión.

---

## 2. Detalle de fallos y correcciones aplicadas

### 2.1 FEFO no se aplicaba en el servidor — CORREGIDO
**Antes:** `sp_Movimientos_RegistrarSalida` exigía `@id_lote`; el operador elegía el lote manualmente y la regla FEFO dependía de la interfaz.
**Ahora:** `@id_lote` es opcional. Si llega `NULL`, el SP selecciona con `TOP (1)` el lote vigente (`fecha_vencimiento > hoy` o sin vencimiento) con vencimiento más próximo que cubra la cantidad; los lotes sin vencimiento quedan al final. Si ningún lote individual alcanza, responde `51209` (409). El resultado devuelve `id_lote` y `numero_lote`, y el frontend ofrece la opción **Automático (FEFO)**.

### 2.2 Criterio de vencimiento inconsistente — CORREGIDO
**Antes:** SQL y frontend usaban `< hoy`, por lo que un lote que vencía hoy seguía siendo despachable.
**Ahora:** se unificó a `fecha_vencimiento <= hoy` como vencido en `sp_Movimientos_RegistrarSalida`, `sp_Lotes_ListarPorProducto`, `sp_Lotes_Obtener` y en el filtro del formulario. Un lote que vence hoy se bloquea con `51208` (409).

### 2.3 Ventanas de alertas mal acotadas — CORREGIDO
**Antes:** “por vencer” usaba `BETWEEN hoy AND hoy+30` (incluía el día actual) y “vencidos” usaba `< hoy` (excluía hoy).
**Ahora:** el estado `VENCIDO` se calcula con `<= hoy`; por tanto `sp_Alertas_PorVencer` con 30 días devuelve exactamente 1..30 días como `PROXIMO`, y con 0 días devuelve todos los vencidos, incluido el día actual. El dashboard cuenta vencidos con `<= hoy` y próximos entre mañana y 30 días. El stock disponible excluye los lotes que vencen hoy.

### 2.4 Área desactivable con movimientos — CORREGIDO
**Antes:** `sp_Areas_Desactivar` solo cambiaba `activo = 0`.
**Ahora:** valida existencia (`51503`) y rechaza la desactivación si el área tiene movimientos (`51504` → 409), preservando la trazabilidad de los consumos. Mapeo agregado en `area_repository.py`.

### 2.5 Auditoría de movimientos incompleta — CORREGIDO
**Antes:** la auditoría se escribía desde Python en modo *best-effort* después del movimiento: podía perderse y no registraba el área de forma estructurada (solo en texto).
**Ahora:** entradas y salidas insertan su fila en `dbo.Auditoria` **dentro de la misma transacción del SP**, por lo que la cobertura es total y consistente. Se agregó la columna `id_area` a `Auditoria` (migración idempotente en `02_rbac_tablas.sql`) y el parámetro `@id_area` a `sp_Auditoria_Registrar`. Se eliminaron las llamadas duplicadas desde `movimiento_service.py`.

### 2.6 Cuenta semilla sin protección específica — CORREGIDO
**Antes:** solo se impedía dejar el sistema sin administradores activos; `admin.desarrollo@sigih.test` podía desactivarse si existía otro administrador, cambiarse de correo o perder el rol.
**Ahora:** `sp_Usuarios_Actualizar`, `sp_Usuarios_Desactivar` y `sp_Usuarios_QuitarRol` lanzan `52005` (409) al intentar desactivar la cuenta, cambiar su correo o retirarle `ADMINISTRADOR`.

### 2.7 `ProductoActualizar` aceptaba campos extra en silencio — CORREGIDO
**Antes:** el `PUT` ignoraba campos desconocidos (incluido un intento de enviar stock).
**Ahora:** `model_config = ConfigDict(extra="forbid")` responde 422, igual que entradas y salidas. El stock sigue sin exponerse en el schema.

---

## 3. Evidencia de verificación

| Prueba | Resultado |
|---|---|
| `npm run build` (Angular) | Correcto |
| `npm test -- --watch=false` | 4 archivos / 9 pruebas aprobadas |
| `python -m compileall` + importación de `backend.main` | Correcto |
| `database/99_verificar.sql` | 50 SP, RBAC y permisos de `sigih_app` correctos |
| Salida FEFO automática (transacción + rollback) | Lote `GAS-2601` (vencimiento más próximo) y auditoría con `id_area = 1` |
| Desactivar cuenta semilla | `52005` — bloqueado |
| Quitar rol ADMINISTRADOR a la semilla | `52005` — bloqueado |
| Desactivar área con movimientos | `51504` — bloqueado |
| Salida con lote que vence hoy | `51208` — bloqueado (API 409) |
| Salida FEFO sin stock suficiente | 409 controlado (API) |
| Alertas: por vencer / vencidos | 2 lotes (1..30 días) / 1 lote (≤ hoy) |
| Descuadres de stock/kardex y duplicados | 0 |

---

## 4. Plan de Corrección Sugerido

### Aplicado en esta iteración

1. **FEFO server-side:** `@id_lote` opcional y selección del lote con vencimiento más próximo en `08_sp_movimientos.sql`.
2. **Vencimiento unificado:** `<= hoy` en SP de salida, SP de lotes y formulario.
3. **Alertas:** `VENCIDO` con `<= hoy`; `PROXIMO` como ventana 1..30; dashboard alineado.
4. **Áreas:** validación de movimientos en `sp_Areas_Desactivar` (51504).
5. **Auditoría transaccional:** `INSERT` en `dbo.Auditoria` dentro de los SP de entrada/salida, con `id_area`.
6. **Cuenta semilla:** bloqueo de desactivación, cambio de correo y retiro de ADMINISTRADOR (52005).
7. **Productos:** `extra="forbid"` en `ProductoActualizar`.
8. **Instalador:** `database/INSTALAR_SIGIH.sql` regenerado con las secciones 02, 03, 07, 08, 09, 10 y 12 actualizadas.

### Recomendaciones pendientes (no bloqueantes)

1. **Refresco de permisos en el frontend:** tras cambiar roles/permisos, el menú no se recalcula hasta recargar. Opción: volver a llamar `GET /api/auth/me` después de guardar en Usuarios/Roles.
2. **FEFO multi-lote:** hoy la salida consume un solo lote. Si el negocio requiere despachar una cantidad mayor que cualquier lote individual, habría que generar varias filas de movimiento (una por lote) en una sola transacción.
3. **Cobertura automatizada:** agregar pruebas de integración de los códigos 51208/51209/51504/52005 y del cálculo FEFO para evitar regresiones.
4. **Refresco del dashboard:** si se requiere que el resumen cambie sin abrir la vista, invalidar su caché también cuando el dashboard no se ha cargado.

---

*No se realizaron commits ni push. Los scripts SQL modificados ya fueron aplicados sobre `SIGIH` y son idempotentes.*
