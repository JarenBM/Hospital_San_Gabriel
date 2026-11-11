import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import type { FiltrosProducto, ProductoListado } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ConfirmacionService } from '../../core/services/confirmacion.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { formatearMoneda } from '../../core/utils/formato';
import { Modal } from '../../shared/components/modal/modal';
import { Paginador } from '../../shared/components/paginador/paginador';

/** Opciones del filtro por estado del producto. */
type FiltroEstado = 'todos' | 'activos' | 'inactivos';

/** Campos de texto del formulario de producto. */
type CampoTextoProducto =
  'codigo' | 'nombre' | 'descripcion' | 'unidadMedida' | 'precioUnitario' | 'stockMinimo';

/** Campos booleanos del formulario de producto. */
type CampoBooleanoProducto = 'manejaLotes' | 'requiereVencimiento';

const MAX_CODIGO = 30;
const MAX_NOMBRE = 150;
const MAX_DESCRIPCION = 500;
const MAX_UNIDAD = 30;
const MAX_ENTERO = 2_147_483_647;

/**
 * Catálogo de productos.
 *
 * Filtros y paginación se resuelven en el servidor sobre
 * ``ApiService.productosPagina`` y protege las escrituras con el permiso
 * ``productos:escribir``. El formulario usa un signal por campo y validaciones
 * equivalentes a las de Pydantic.
 */
@Component({
  selector: 'app-productos',
  imports: [Modal, Paginador],
  templateUrl: './productos.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './productos.scss',
})
export class Productos implements OnInit {
  protected readonly auth = inject(AuthService);
  private readonly api = inject(ApiService);
  private readonly toasts = inject(ToastService);
  private readonly confirmacion = inject(ConfirmacionService);

  protected readonly productos = this.api.productosPagina;
  protected readonly categorias = this.api.categorias;
  protected readonly formatearMoneda = formatearMoneda;

  protected readonly puedeEscribir = computed(() => this.auth.tienePermiso('productos:escribir'));

  // ---------- Filtros ----------

  protected readonly filtroBusqueda = signal('');
  protected readonly filtroCategoria = signal<number | null>(null);
  protected readonly filtroEstado = signal<FiltroEstado>('todos');

  protected readonly pagina = signal(1);
  protected readonly tamano = 25;

  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.productos.total() / this.tamano)),
  );

  protected readonly desdeRegistro = computed(() =>
    this.productos.datos().length === 0 ? 0 : (this.pagina() - 1) * this.tamano + 1,
  );

  protected readonly hastaRegistro = computed(
    () => (this.pagina() - 1) * this.tamano + this.productos.datos().length,
  );

  private temporizadorBusqueda?: ReturnType<typeof setTimeout>;

  protected readonly hayFiltros = computed(
    () =>
      this.filtroBusqueda().trim() !== '' ||
      this.filtroCategoria() !== null ||
      this.filtroEstado() !== 'todos',
  );

  // ---------- Modal ----------

  protected readonly modalAbierto = signal(false);
  protected readonly productoEditando = signal<ProductoListado | null>(null);
  protected readonly guardando = signal(false);
  protected readonly errorModal = signal<string | null>(null);
  protected readonly intentado = signal(false);

  // ---------- Formulario ----------

  protected readonly codigo = signal('');
  protected readonly nombre = signal('');
  protected readonly descripcion = signal('');
  protected readonly idCategoria = signal<number | null>(null);
  protected readonly unidadMedida = signal('');
  protected readonly precioUnitario = signal('');
  protected readonly stockMinimo = signal('0');
  protected readonly manejaLotes = signal(false);
  protected readonly requiereVencimiento = signal(false);

  // ---------- Derivados ----------

  /** La página ya viene filtrada y paginada del servidor. */
  protected readonly productosFiltrados = computed(() => this.productos.datos());

  protected readonly cargandoInicial = computed(
    () => this.productos.cargando() && this.productos.datos().length === 0,
  );

  protected readonly esEdicion = computed(() => this.productoEditando() !== null);

  protected readonly tituloModal = computed(() =>
    this.esEdicion() ? 'Editar producto' : 'Nuevo producto',
  );

  // ---------- Validaciones ----------

  protected readonly errorCodigo = computed<string | null>(() => {
    const valor = this.codigo().trim();
    if (!valor) {
      return 'El código es obligatorio.';
    }
    if (valor.length > MAX_CODIGO) {
      return `El código no puede superar los ${MAX_CODIGO} caracteres.`;
    }
    return null;
  });

  protected readonly errorNombre = computed<string | null>(() => {
    const valor = this.nombre().trim();
    if (!valor) {
      return 'El nombre es obligatorio.';
    }
    if (valor.length > MAX_NOMBRE) {
      return `El nombre no puede superar los ${MAX_NOMBRE} caracteres.`;
    }
    return null;
  });

  protected readonly errorDescripcion = computed<string | null>(() => {
    if (this.descripcion().trim().length > MAX_DESCRIPCION) {
      return `La descripción no puede superar los ${MAX_DESCRIPCION} caracteres.`;
    }
    return null;
  });

  protected readonly errorIdCategoria = computed<string | null>(() => {
    const id = this.idCategoria();
    if (id === null) {
      return 'Seleccione una categoría.';
    }
    const existe = this.categorias.datos().some((categoria) => categoria.id_categoria === id);
    return existe ? null : 'Seleccione una categoría válida.';
  });

  protected readonly errorUnidadMedida = computed<string | null>(() => {
    const valor = this.unidadMedida().trim();
    if (!valor) {
      return 'La unidad de medida es obligatoria.';
    }
    if (valor.length > MAX_UNIDAD) {
      return `La unidad no puede superar los ${MAX_UNIDAD} caracteres.`;
    }
    return null;
  });

  protected readonly errorPrecioUnitario = computed<string | null>(() => {
    const valor = this.precioUnitario().trim();
    if (!valor) {
      return 'El precio unitario es obligatorio.';
    }
    if (!/^\d{1,10}(\.\d{1,2})?$/.test(valor)) {
      return 'Ingrese un precio con hasta 10 enteros y 2 decimales.';
    }
    const numero = Number(valor);
    if (!Number.isFinite(numero) || numero <= 0) {
      return 'El precio debe ser mayor que 0.';
    }
    return null;
  });

  protected readonly errorStockMinimo = computed<string | null>(() => {
    const valor = this.stockMinimo().trim();
    if (!valor) {
      return 'El stock mínimo es obligatorio.';
    }
    if (!/^\d+$/.test(valor)) {
      return 'Ingrese un número entero mayor o igual a 0.';
    }
    const numero = Number(valor);
    if (!Number.isSafeInteger(numero) || numero > MAX_ENTERO) {
      return 'El stock mínimo está fuera del rango permitido.';
    }
    return null;
  });

  protected readonly errorManejaLotes = computed<string | null>(() => {
    if (this.requiereVencimiento() && !this.manejaLotes()) {
      return 'Para requerir vencimiento, el producto debe manejar lotes.';
    }
    return null;
  });

  protected readonly formularioValido = computed(
    () =>
      this.errorCodigo() === null &&
      this.errorNombre() === null &&
      this.errorDescripcion() === null &&
      this.errorIdCategoria() === null &&
      this.errorUnidadMedida() === null &&
      this.errorPrecioUnitario() === null &&
      this.errorStockMinimo() === null &&
      this.errorManejaLotes() === null,
  );

  ngOnInit(): void {
    this.recargarProductos();
    this.recargarCategorias();
  }

  // ---------- Carga ----------

  protected recargarProductos(): void {
    this.api
      .cargarProductosPagina(this.filtrosServidor())
      .subscribe({ error: () => undefined });
  }

  protected recargarCategorias(): void {
    this.api.cargarCategorias().subscribe({ error: () => undefined });
  }

  // ---------- Filtros ----------

  protected cambiarFiltroBusqueda(evento: Event): void {
    this.filtroBusqueda.set(this.valorDe(evento));
    this.reiniciarPaginaConRetraso();
  }

  protected cambiarFiltroCategoria(evento: Event): void {
    const valor = this.valorDe(evento);
    this.filtroCategoria.set(valor ? Number(valor) : null);
    this.reiniciarPaginaYRecargar();
  }

  protected cambiarFiltroEstado(evento: Event): void {
    const valor = this.valorDe(evento);
    this.filtroEstado.set(
      valor === 'activos' || valor === 'inactivos' ? valor : 'todos',
    );
    this.reiniciarPaginaYRecargar();
  }

  protected limpiarFiltros(): void {
    this.filtroBusqueda.set('');
    this.filtroCategoria.set(null);
    this.filtroEstado.set('todos');
    this.reiniciarPaginaYRecargar();
  }

  protected irPagina(pagina: number): void {
    this.pagina.set(pagina);
    this.recargarProductos();
  }

  // ---------- Modal ----------

  protected abrirCrear(): void {
    if (!this.puedeEscribir()) {
      return;
    }
    this.prepararFormulario(null);
  }

  protected abrirEditar(producto: ProductoListado): void {
    if (!this.puedeEscribir()) {
      return;
    }
    this.prepararFormulario(producto);
  }

  protected cerrarModal(): void {
    if (this.guardando()) {
      return;
    }
    this.modalAbierto.set(false);
    this.errorModal.set(null);
    this.intentado.set(false);
  }

  protected cambiarTexto(campo: CampoTextoProducto, evento: Event): void {
    const valor = this.valorDe(evento);
    switch (campo) {
      case 'codigo':
        this.codigo.set(valor);
        break;
      case 'nombre':
        this.nombre.set(valor);
        break;
      case 'descripcion':
        this.descripcion.set(valor);
        break;
      case 'unidadMedida':
        this.unidadMedida.set(valor);
        break;
      case 'precioUnitario':
        this.precioUnitario.set(valor);
        break;
      case 'stockMinimo':
        this.stockMinimo.set(valor);
        break;
    }
  }

  protected cambiarCategoria(evento: Event): void {
    const valor = this.valorDe(evento);
    this.idCategoria.set(valor ? Number(valor) : null);
  }

  protected cambiarBooleano(campo: CampoBooleanoProducto, evento: Event): void {
    if (this.esEdicion()) {
      return;
    }

    const marcado = this.marcadoDe(evento);
    if (campo === 'manejaLotes') {
      this.manejaLotes.set(marcado);
      if (!marcado) {
        this.requiereVencimiento.set(false);
      }
      return;
    }

    const manejaLotes = this.manejaLotes();
    if (!manejaLotes) {
      this.requiereVencimiento.set(false);
      return;
    }
    this.requiereVencimiento.set(marcado);
  }

  protected guardar(evento: Event): void {
    evento.preventDefault();
    this.intentado.set(true);

    if (this.guardando() || !this.formularioValido()) {
      return;
    }

    const idCategoria = this.idCategoria();
    if (idCategoria === null) {
      return;
    }

    const editando = this.productoEditando();
    const datosBase = {
      id_categoria: idCategoria,
      codigo: this.codigo().trim(),
      nombre: this.nombre().trim(),
      descripcion: this.descripcion().trim() || null,
      unidad_medida: this.unidadMedida().trim(),
      precio_unitario: this.precioUnitario().trim(),
      stock_minimo: Number(this.stockMinimo().trim()),
    };

    this.guardando.set(true);
    this.errorModal.set(null);

    const peticion = editando
      ? this.api.actualizarProducto(editando.id_producto, datosBase)
      : this.api.crearProducto({
          ...datosBase,
          maneja_lotes: this.manejaLotes(),
          requiere_vencimiento: this.requiereVencimiento(),
        });

    peticion.subscribe({
      next: (producto) => {
        this.guardando.set(false);
        this.modalAbierto.set(false);
        this.errorModal.set(null);
        this.intentado.set(false);
        this.toasts.exito(
          editando ? 'Producto actualizado' : 'Producto creado',
          `${producto.codigo} · ${producto.nombre}`,
        );
        this.recargarProductos();
      },
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        const texto = detalle ? `${mensaje}: ${detalle}` : mensaje;
        this.guardando.set(false);
        this.errorModal.set(texto);
        this.toasts.error(
          editando ? 'No se pudo actualizar el producto' : 'No se pudo crear el producto',
          texto,
        );
      },
    });
  }

  protected async desactivar(producto: ProductoListado): Promise<void> {
    if (!this.puedeEscribir()) {
      return;
    }

    const confirmado = await this.confirmacion.confirmar({
      titulo: 'Desactivar producto',
      mensaje: `¿Desea desactivar "${producto.nombre}"?`,
      detalle:
        'Dejará de estar disponible para nuevas entradas y salidas. Los productos no se pueden reactivar desde el sistema.',
      textoConfirmar: 'Desactivar',
      variante: 'peligro',
      icono: 'bi-box-seam',
    });

    if (!confirmado) {
      return;
    }

    this.api.desactivarProducto(producto.id_producto).subscribe({
      next: () => {
        this.toasts.exito('Producto desactivado', `${producto.codigo} · ${producto.nombre}`);
        this.recargarProductos();
      },
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        this.toasts.error('No se pudo desactivar el producto', detalle ?? mensaje);
      },
    });
  }

  // ---------- Presentación ----------

  protected claseStock(producto: ProductoListado): string {
    if (producto.stock_disponible <= 0) {
      return 'badge text-bg-danger';
    }
    if (producto.stock_disponible <= producto.stock_minimo) {
      return 'badge text-bg-warning';
    }
    return 'badge text-bg-success';
  }

  protected etiquetaStock(producto: ProductoListado): string {
    if (producto.stock_disponible <= 0) {
      return 'Agotado';
    }
    if (producto.stock_disponible <= producto.stock_minimo) {
      return 'Bajo';
    }
    return 'Normal';
  }

  protected claseEstado(activo: boolean): string {
    return activo ? 'badge text-bg-success' : 'badge text-bg-secondary';
  }

  // ---------- Internos ----------

  private reiniciarPaginaYRecargar(): void {
    clearTimeout(this.temporizadorBusqueda);
    this.pagina.set(1);
    this.recargarProductos();
  }

  private reiniciarPaginaConRetraso(): void {
    clearTimeout(this.temporizadorBusqueda);
    this.temporizadorBusqueda = setTimeout(() => {
      this.pagina.set(1);
      this.recargarProductos();
    }, 300);
  }

  private filtrosServidor(): FiltrosProducto {
    const estado = this.filtroEstado();
    return {
      busqueda: this.filtroBusqueda().trim() || null,
      id_categoria: this.filtroCategoria(),
      solo_activos: estado === 'todos' ? null : estado === 'activos',
      pagina: this.pagina(),
      tamano: this.tamano,
    };
  }

  private prepararFormulario(producto: ProductoListado | null): void {
    this.productoEditando.set(producto);
    this.codigo.set(producto?.codigo ?? '');
    this.nombre.set(producto?.nombre ?? '');
    this.descripcion.set(producto?.descripcion ?? '');
    this.idCategoria.set(producto?.id_categoria ?? null);
    this.unidadMedida.set(producto?.unidad_medida ?? '');
    this.precioUnitario.set(producto?.precio_unitario ?? '');
    this.stockMinimo.set(producto ? String(producto.stock_minimo) : '0');
    this.manejaLotes.set(producto?.maneja_lotes ?? false);
    this.requiereVencimiento.set(producto?.requiere_vencimiento ?? false);
    this.errorModal.set(null);
    this.intentado.set(false);
    this.modalAbierto.set(true);
  }

  private valorDe(evento: Event): string {
    const objetivo = evento.target;
    if (
      objetivo instanceof HTMLInputElement ||
      objetivo instanceof HTMLTextAreaElement ||
      objetivo instanceof HTMLSelectElement
    ) {
      return objetivo.value;
    }
    return '';
  }

  private marcadoDe(evento: Event): boolean {
    const objetivo = evento.target;
    return objetivo instanceof HTMLInputElement ? objetivo.checked : false;
  }
}
