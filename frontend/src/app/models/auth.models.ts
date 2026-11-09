/** Contratos de autenticación. */

/** Cuerpo del formulario OAuth2 que consume ``POST /api/auth/login``. */
export interface CredencialesLogin {
  /** El backend espera el correo en el campo ``username``. */
  username: string;
  password: string;
}

/** Respuesta de ``POST /api/auth/login``. */
export interface TokenRespuesta {
  access_token: string;
  token_type: 'bearer';
  /** Vigencia del token en segundos. */
  expira_en: number;
}

/** Respuesta de ``GET /api/auth/me``. Nunca incluye ``password_hash``. */
export interface UsuarioAutenticado {
  id_usuario: number;
  nombre: string;
  email: string;
  activo: boolean;
  /** Nombres de los roles activos, por ejemplo ``["ADMINISTRADOR"]``. */
  roles: string[];
  /** Códigos ``modulo:accion`` de los permisos efectivos. */
  permisos: string[];
}
