import type { Id } from './api.models';

/** Contratos de usuarios (``/api/usuarios``). */

/** Fila de ``sp_Usuarios_Obtener`` / ``sp_Usuarios_Listar``. */
export interface Usuario {
  id_usuario: Id;
  nombre: string;
  email: string;
  activo: boolean;
  /** Fecha y hora ISO 8601. */
  fecha_creacion: string;
  /** Roles concatenados que devuelve el SP, por ejemplo ``"ADMINISTRADOR"``. */
  roles: string | null;
}

/** Cuerpo de ``POST /api/usuarios``. */
export interface UsuarioCrear {
  nombre: string;
  email: string;
  /** Contraseña en claro; el backend la hashea con Argon2id. */
  password: string;
  id_rol?: Id | null;
}

/** Cuerpo de ``PUT /api/usuarios/{id}``. ``activo`` nulo conserva el estado. */
export interface UsuarioActualizar {
  nombre: string;
  email: string;
  activo?: boolean | null;
}

/** Cuerpo de ``PUT /api/usuarios/{id}/password``. */
export interface UsuarioPassword {
  password: string;
}

/** Cuerpo de ``POST /api/usuarios/{id}/roles``. */
export interface UsuarioRol {
  id_rol: Id;
}

/** Filtros de ``GET /api/usuarios``. */
export interface FiltrosUsuario {
  busqueda?: string | null;
  id_rol?: Id | null;
  solo_activos?: boolean | null;
}
