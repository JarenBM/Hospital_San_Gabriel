/**
 * Punto único de importación de los contratos de la API SIGIH.
 *
 * Uso:
 * ```ts
 * import type { ProductoListado, MovimientoListado } from '../../models';
 * import { MOTIVOS_ENTRADA } from '../../models';
 * ```
 */

export type {
  ApiError,
  ApiValidationIssue,
  DecimalString,
  FechaHoraISO,
  FechaISO,
  FiltrosBase,
  Id,
  Paginacion,
  RespuestaTotal,
} from './api.models';

export type {
  CredencialesLogin,
  TokenRespuesta,
  UsuarioAutenticado,
} from './auth.models';

export type {
  FiltrosUsuario,
  Usuario,
  UsuarioActualizar,
  UsuarioCrear,
  UsuarioPassword,
  UsuarioRol,
} from './usuario.models';

export type {
  CodigoPermiso,
  Permiso,
  PermisoAsignado,
  PermisoCatalogo,
  Rol,
  RolActualizar,
  RolCrear,
  RolPermisos,
} from './rol.models';
export { MODULOS_PERMISO, PERMISOS_CATALOGO } from './rol.models';

export type {
  Categoria,
  CategoriaActualizar,
  CategoriaCrear,
} from './categoria.models';

export type {
  FiltrosProducto,
  Producto,
  ProductoActualizar,
  ProductoCrear,
  ProductoListado,
} from './producto.models';

export type { Lote } from './lote.models';

export type {
  EntradaCrear,
  EntradaRegistrada,
  FiltrosMovimiento,
  MotivoEntrada,
  MovimientoListado,
  SalidaCrear,
  SalidaRegistrada,
  TipoMovimiento,
} from './movimiento.models';
export { MOTIVOS_ENTRADA } from './movimiento.models';

export type { Area, AreaActualizar, AreaCrear } from './area.models';

export type {
  EstadoVencimiento,
  LoteAlerta,
  ProductoStockBajo,
  ResumenInventario,
} from './alerta.models';

export type {
  ConsumoArea,
  FiltrosMayoresSalidas,
  MayorSalida,
  RangoReporte,
  StockValorizado,
} from './reporte.models';
