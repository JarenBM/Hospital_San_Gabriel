import type { Id } from './api.models';

/** Contratos de roles y permisos (``/api/roles``, ``/api/permisos``). */

/** Códigos de permiso sembrados por ``database/15_seed_rbac.sql``. */
export type CodigoPermiso =
  | 'categorias:leer'
  | 'categorias:escribir'
  | 'productos:leer'
  | 'productos:escribir'
  | 'lotes:leer'
  | 'movimientos:leer'
  | 'movimientos:entrada'
  | 'movimientos:salida'
  | 'areas:leer'
  | 'areas:escribir'
  | 'alertas:leer'
  | 'dashboard:leer'
  | 'reportes:leer'
  | 'usuarios:gestionar'
  | 'roles:gestionar'
  | 'auditoria:leer';

/** Fila de ``sp_Roles_Listar`` / ``sp_Roles_Obtener``. */
export interface Rol {
  id_rol: Id;
  nombre: string;
  descripcion: string | null;
  activo: boolean;
  total_permisos: number;
}

/** Cuerpo de ``POST /api/roles``. */
export interface RolCrear {
  nombre: string;
  descripcion?: string | null;
}

/** Cuerpo de ``PUT /api/roles/{id}``. ``activo`` nulo conserva el estado. */
export interface RolActualizar {
  nombre: string;
  descripcion?: string | null;
  activo?: boolean | null;
}

/** Fila de ``sp_Permisos_Listar`` / ``sp_Permisos_Obtener``. */
export interface Permiso {
  id_permiso: Id;
  codigo: string;
  modulo: string;
  descripcion: string | null;
}

/** Permiso efectivo devuelto por ``GET /api/usuarios/{id}/permisos``. */
export interface PermisoAsignado {
  codigo: string;
  modulo: string;
}

/** Cuerpo de ``PUT /api/roles/{id}/permisos``. */
export interface RolPermisos {
  permisos: string[];
}

/** Entrada del catálogo de permisos, útil para pintar la matriz de roles. */
export interface PermisoCatalogo {
  codigo: CodigoPermiso;
  modulo: string;
  descripcion: string;
}

/** Catálogo de permisos del sistema, en el mismo orden que el seed SQL. */
export const PERMISOS_CATALOGO: readonly PermisoCatalogo[] = [
  { codigo: 'categorias:leer', modulo: 'categorias', descripcion: 'Consultar categorías' },
  {
    codigo: 'categorias:escribir',
    modulo: 'categorias',
    descripcion: 'Crear, editar y desactivar categorías',
  },
  { codigo: 'productos:leer', modulo: 'productos', descripcion: 'Consultar productos' },
  {
    codigo: 'productos:escribir',
    modulo: 'productos',
    descripcion: 'Crear, editar y desactivar productos',
  },
  { codigo: 'lotes:leer', modulo: 'lotes', descripcion: 'Consultar lotes' },
  { codigo: 'movimientos:leer', modulo: 'movimientos', descripcion: 'Consultar movimientos' },
  { codigo: 'movimientos:entrada', modulo: 'movimientos', descripcion: 'Registrar entradas' },
  { codigo: 'movimientos:salida', modulo: 'movimientos', descripcion: 'Registrar salidas' },
  { codigo: 'areas:leer', modulo: 'areas', descripcion: 'Consultar áreas' },
  {
    codigo: 'areas:escribir',
    modulo: 'areas',
    descripcion: 'Crear, editar y desactivar áreas',
  },
  { codigo: 'alertas:leer', modulo: 'alertas', descripcion: 'Consultar alertas de inventario' },
  { codigo: 'dashboard:leer', modulo: 'dashboard', descripcion: 'Consultar el dashboard' },
  { codigo: 'reportes:leer', modulo: 'reportes', descripcion: 'Consultar reportes' },
  { codigo: 'usuarios:gestionar', modulo: 'usuarios', descripcion: 'Gestionar usuarios' },
  { codigo: 'roles:gestionar', modulo: 'roles', descripcion: 'Gestionar roles y permisos' },
  { codigo: 'auditoria:leer', modulo: 'auditoria', descripcion: 'Consultar auditoría' },
] as const;

/** Módulos únicos presentes en el catálogo. */
export const MODULOS_PERMISO: readonly string[] = [
  ...new Set(PERMISOS_CATALOGO.map((permiso) => permiso.modulo)),
];
