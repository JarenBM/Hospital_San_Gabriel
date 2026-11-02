import type { CodigoPermiso } from '../../../models';

/** Grupos visuales del menú lateral, en el orden en que se pintan. */
export type GrupoNavegacion = 'Principal' | 'Inventario' | 'Administración';

export interface OpcionNavegacion {
  /** Texto visible en el sidebar y en el título del navbar. */
  etiqueta: string;
  /** Ruta absoluta de Angular. */
  ruta: string;
  /** Clase de Bootstrap Icons. */
  icono: string;
  /** Permiso necesario para ver la opción. Sin permiso, siempre visible. */
  permiso?: CodigoPermiso;
  grupo: GrupoNavegacion;
  descripcion: string;
  /** ``true`` para ``routerLinkActive`` exacto (dashboard). */
  exacto?: boolean;
}

/**
 * Catálogo único de navegación.
 *
 * El sidebar filtra esta lista con ``AuthService.tienePermiso()``. Las rutas
 * de módulos aún no implementados muestran una página de "en construcción".
 */
export const NAVEGACION: readonly OpcionNavegacion[] = [
  {
    etiqueta: 'Dashboard',
    ruta: '/dashboard',
    icono: 'bi-speedometer2',
    permiso: 'dashboard:leer',
    grupo: 'Principal',
    descripcion: 'Resumen general del inventario hospitalario.',
    exacto: true,
  },
  {
    etiqueta: 'Productos',
    ruta: '/productos',
    icono: 'bi-box-seam',
    permiso: 'productos:leer',
    grupo: 'Inventario',
    descripcion: 'Catálogo de productos, precios y stock mínimo.',
  },
  {
    etiqueta: 'Categorías',
    ruta: '/categorias',
    icono: 'bi-tags',
    permiso: 'categorias:leer',
    grupo: 'Inventario',
    descripcion: 'Agrupación y clasificación de productos.',
  },
  {
    etiqueta: 'Lotes',
    ruta: '/lotes',
    icono: 'bi-upc-scan',
    permiso: 'lotes:leer',
    grupo: 'Inventario',
    descripcion: 'Existencias por lote y control de vencimientos.',
  },
  {
    etiqueta: 'Movimientos',
    ruta: '/movimientos',
    icono: 'bi-arrow-left-right',
    permiso: 'movimientos:leer',
    grupo: 'Inventario',
    descripcion: 'Entradas y salidas de inventario por área.',
  },
  {
    etiqueta: 'Alertas',
    ruta: '/alertas',
    icono: 'bi-bell',
    permiso: 'alertas:leer',
    grupo: 'Inventario',
    descripcion: 'Stock bajo, lotes por vencer y lotes vencidos.',
  },
  {
    etiqueta: 'Reportes',
    ruta: '/reportes',
    icono: 'bi-graph-up-arrow',
    permiso: 'reportes:leer',
    grupo: 'Inventario',
    descripcion: 'Stock valorizado, consumo por área y mayores salidas.',
  },
  {
    etiqueta: 'Áreas',
    ruta: '/areas',
    icono: 'bi-hospital',
    permiso: 'areas:leer',
    grupo: 'Administración',
    descripcion: 'Áreas hospitalarias que reciben inventario.',
  },
  {
    etiqueta: 'Usuarios',
    ruta: '/usuarios',
    icono: 'bi-people',
    permiso: 'usuarios:gestionar',
    grupo: 'Administración',
    descripcion: 'Cuentas, roles y estado de los usuarios.',
  },
  {
    etiqueta: 'Roles',
    ruta: '/roles',
    icono: 'bi-shield-lock',
    permiso: 'roles:gestionar',
    grupo: 'Administración',
    descripcion: 'Roles y matriz de permisos módulo:acción.',
  },
];

/** Orden fijo de los grupos del menú. */
export const GRUPOS_NAVEGACION: readonly GrupoNavegacion[] = [
  'Principal',
  'Inventario',
  'Administración',
];

/** Busca la opción de navegación activa para una URL. */
export function opcionPorUrl(url: string): OpcionNavegacion | undefined {
  const limpia = url.split('?')[0].split('#')[0];
  return NAVEGACION.find(
    (opcion) => limpia === opcion.ruta || limpia.startsWith(`${opcion.ruta}/`),
  );
}
