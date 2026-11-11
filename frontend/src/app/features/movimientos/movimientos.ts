import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import { finalize } from 'rxjs';
import type { FiltrosMovimiento, Lote, MotivoEntrada, TipoMovimiento } from '../../models';
import { MOTIVOS_ENTRADA } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import {
  fechaHoyISO,
  formatearFecha,
  formatearFechaHora,
  formatearNumero,
} from '../../core/utils/formato';
import { Modal } from '../../shared/components/modal/modal';
import { Paginador } from '../../shared/components/paginador/paginador';

type FiltroTipo = 'TODOS' | TipoMovimiento;

interface ErroresEntrada {
  idProducto: string | null;
  cantidad: string | null;
  motivo: string | null;
  numeroLote: string | null;
  fechaVencimiento: string | null;
}

interface ErroresSalida {
  idProducto: string | null;
  idArea: string | null;
  cantidad: string | null;
  motivo: string | null;
}

/**
 * Historial de movimientos y registro de entradas y salidas.
 *
 * Los filtros se resuelven en el servidor y el historial se pagina; el
 * formulario de entrada solo pide lote y vencimiento cuando el producto los
 * maneja; el de salida ofrece lotes vigentes y, si no se elige uno, el
 * backend aplica FEFO automáticamente.
 */
@Component({
  selector: 'app-movimientos',
  imports: [Modal, Paginador],
  templateUrl: './movimientos.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './movimientos.scss',
})
export class Movimientos implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly toasts = inject(ToastService);

  protected readonly movimientos = this.api.movimientos;
  protected readonly productos = this.api.productosActivos;
  protected readonly areas = this.api.areas.datos;
  protected readonly areasActivas = this.api.areasActivas;
  protected readonly cargandoProductos = this.api.productos.cargando;
  protected readonly cargandoAreas = this.api.areas.cargando;

  protected readonly puedeLeer = computed(() => this.auth.tienePermiso('movimientos:leer'));
  protected readonly puedeEntrada = computed(() => this.auth.tienePermiso('movimientos:entrada'));
  protected readonly puedeSalida = computed(() => this.auth.tienePermiso('movimientos:salida'));

  protected readonly formatearFecha = formatearFecha;
  protected readonly formatearFechaHora = formatearFechaHora;
  protected readonly formatearNumero = formatearNumero;
  /** Catálogo del backend; la constante local queda como respaldo offline. */
  protected readonly motivosEntrada = signal<readonly MotivoEntrada[]>(MOTIVOS_ENTRADA);
  protected readonly tiposFiltro: readonly FiltroTipo[] = ['TODOS', 'ENTRADA', 'SALIDA'];
  protected readonly hoy = fechaHoyISO();

  // ---------- Filtros ----------

  protected readonly busqueda = signal('');
  protected readonly tipoFiltro = signal<FiltroTipo>('TODOS');
  protected readonly idAreaFiltro = signal<number | null>(null);
  protected readonly desde = signal('');
  protected readonly hasta = signal('');

  protected readonly pagina = signal(1);
  protected readonly tamano = 25;

  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.movimientos.total() / this.tamano)),
  );

  protected readonly desdeRegistro = computed(() =>
    this.movimientos.datos().length === 0
      ? 0
      : (this.pagina() - 1) * this.tamano + 1,
  );

  protected readonly hastaRegistro = computed(
    () => (this.pagina() - 1) * this.tamano + this.movimientos.datos().length,
  );

  protected readonly hayFiltros = computed(
    () =>
      this.busqueda().trim() !== '' ||
      this.tipoFiltro() !== 'TODOS' ||
      this.idAreaFiltro() !== null ||
      this.desde() !== '' ||
      this.hasta() !== '',
  );

  private temporizadorBusqueda?: ReturnType<typeof setTimeout>;

  protected readonly rangoInvalido = computed(
    () => this.desde() !== '' && this.hasta() !== '' && this.desde() > this.hasta(),
  );

  protected readonly totalMovimientos = computed(() => this.movimientos.total());

  /** La página ya viene filtrada y paginada del servidor. */
  protected readonly movimientosFiltrados = computed(() => this.movimientos.datos());

  // ---------- Modales ----------

  protected readonly modalEntrada = signal(false);
  protected readonly modalSalida = signal(false);
  protected readonly guardando = signal(false);

  // ---------- Formulario de entrada ----------

  protected readonly idProductoEntrada = signal<number | null>(null);
  protected readonly cantidadEntrada = signal('');
  protected readonly motivoEntrada = signal<MotivoEntrada | ''>('');
  protected readonly numeroLoteEntrada = signal('');
  protected readonly fechaVencimientoEntrada = signal('');
  protected readonly intentoEntrada = signal(false);

  protected readonly productoEntrada = computed(() => {
    const id = this.idProductoEntrada();
    if (id === null) {
      return null;
    }
    return this.productos().find((producto) => producto.id_producto === id) ?? null;
  });

  protected readonly erroresEntrada = computed<ErroresEntrada>(() => {
    const producto = this.productoEntrada();
    const cantidadTexto = this.cantidadEntrada().trim();
    const cantidad = Number(cantidadTexto);
    const numeroLote = this.numeroLoteEntrada().trim();
    const fecha = this.fechaVencimientoEntrada();

    let errorLote: string | null = null;
    if (producto?.maneja_lotes) {
      if (numeroLote === '') {
        errorLote = 'Ingrese el número de lote.';
      } else if (numeroLote.length > 50) {
        errorLote = 'El número de lote no puede superar 50 caracteres.';
      }
    }

    let errorFecha: string | null = null;
    if (producto?.requiere_vencimiento && fecha === '') {
      errorFecha = 'La fecha de vencimiento es obligatoria.';
    } else if (fecha !== '' && fecha < this.hoy) {
      errorFecha = 'La fecha de vencimiento no puede ser anterior a hoy.';
    }

    return {
      idProducto: producto ? null : 'Seleccione un producto.',
      cantidad:
        cantidadTexto === ''
          ? 'Ingrese una cantidad.'
          : !Number.isInteger(cantidad) || cantidad <= 0
            ? 'La cantidad debe ser un entero mayor que 0.'
            : null,
      motivo: this.motivoEntrada() === '' ? 'Seleccione un motivo.' : null,
      numeroLote: errorLote,
      fechaVencimiento: errorFecha,
    };
  });

  protected readonly formularioValidoEntrada = computed(() =>
    Object.values(this.erroresEntrada()).every((error) => error === null),
  );

  // ---------- Formulario de salida ----------

  protected readonly idProductoSalida = signal<number | null>(null);
  protected readonly idLoteSalida = signal<number | null>(null);
  protected readonly idAreaSalida = signal<number | null>(null);
  protected readonly cantidadSalida = signal('');
  protected readonly motivoSalida = signal('');
  protected readonly intentoSalida = signal(false);

  protected readonly lotesSalida = signal<Lote[]>([]);
  protected readonly cargandoLotesSalida = signal(false);
  protected readonly errorLotesSalida = signal<string | null>(null);

  protected readonly productoSalida = computed(() => {
    const id = this.idProductoSalida();
    if (id === null) {
      return null;
    }
    return this.productos().find((producto) => producto.id_producto === id) ?? null;
  });

  protected readonly loteSalida = computed(() => {
    const id = this.idLoteSalida();
    if (id === null) {
      return null;
    }
    return this.lotesSalida().find((lote) => lote.id_lote === id) ?? null;
  });

  protected readonly stockMaximo = computed(() => {
    const lote = this.loteSalida();
    if (lote !== null) {
      return lote.stock_actual;
    }
    // FEFO consume un solo lote: el máximo despachable de una vez es la
    // mayor existencia individual, no la suma de todos los lotes.
    return this.lotesSalida().reduce((mayor, item) => Math.max(mayor, item.stock_actual), 0);
  });

  protected readonly erroresSalida = computed<ErroresSalida>(() => {
    const producto = this.productoSalida();
    const area = this.areasActivas().find((item) => item.id_area === this.idAreaSalida());
    const cantidadTexto = this.cantidadSalida().trim();
    const cantidad = Number(cantidadTexto);
    const motivo = this.motivoSalida().trim();
    const maximo = this.stockMaximo();

    let errorCantidad: string | null = null;
    if (cantidadTexto === '') {
      errorCantidad = 'Ingrese una cantidad.';
    } else if (!Number.isInteger(cantidad) || cantidad <= 0) {
      errorCantidad = 'La cantidad debe ser un entero mayor que 0.';
    } else if (maximo > 0 && cantidad > maximo) {
      errorCantidad = `La cantidad no puede superar el stock disponible (${formatearNumero(maximo)}).`;
    }

    return {
      idProducto: producto ? null : 'Seleccione un producto.',
      idArea: area ? null : 'Seleccione un área.',
      cantidad: errorCantidad,
      motivo:
        motivo === ''
          ? 'Ingrese el motivo de la salida.'
          : motivo.length > 200
            ? 'El motivo no puede superar 200 caracteres.'
            : null,
    };
  });

  protected readonly formularioValidoSalida = computed(() =>
    Object.values(this.erroresSalida()).every((error) => error === null),
  );

  private secuenciaLotesSalida = 0;

  ngOnInit(): void {
    if (!this.puedeLeer()) {
      return;
    }
    this.recargarHistorial();
    this.cargarProductos();
    this.cargarAreas();
    this.cargarMotivosEntrada();
  }

  // ---------- Filtros ----------

  protected actualizarBusqueda(evento: Event): void {
    this.busqueda.set((evento.target as HTMLInputElement).value);
    this.reiniciarPaginaConRetraso();
  }

  protected actualizarTipoFiltro(evento: Event): void {
    const valor = (evento.target as HTMLSelectElement).value;
    if (valor === 'TODOS' || valor === 'ENTRADA' || valor === 'SALIDA') {
      this.tipoFiltro.set(valor);
      this.reiniciarPaginaYRecargar();
    }
  }

  protected actualizarAreaFiltro(evento: Event): void {
    this.idAreaFiltro.set(this.leerId(evento));
    this.reiniciarPaginaYRecargar();
  }

  protected actualizarDesde(evento: Event): void {
    this.desde.set((evento.target as HTMLInputElement).value);
    this.reiniciarPaginaYRecargar();
  }

  protected actualizarHasta(evento: Event): void {
    this.hasta.set((evento.target as HTMLInputElement).value);
    this.reiniciarPaginaYRecargar();
  }

  protected irPagina(pagina: number): void {
    this.pagina.set(pagina);
    this.recargarHistorial();
  }

  protected recargarHistorial(): void {
    if (!this.puedeLeer()) {
      return;
    }
    this.api.cargarMovimientos(this.filtrosServidor()).subscribe({
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        this.toasts.error(mensaje, detalle);
      },
    });
  }

  // ---------- Entrada ----------

  protected abrirEntrada(): void {
    if (!this.puedeEntrada()) {
      return;
    }
    this.reiniciarEntrada();
    this.modalEntrada.set(true);
  }

  protected cerrarEntrada(): void {
    if (this.guardando()) {
      return;
    }
    this.cerrarEntradaAhora();
  }

  protected cambiarProductoEntrada(evento: Event): void {
    this.idProductoEntrada.set(this.leerId(evento));
    this.numeroLoteEntrada.set('');
    this.fechaVencimientoEntrada.set('');
  }

  protected actualizarCantidadEntrada(evento: Event): void {
    this.cantidadEntrada.set((evento.target as HTMLInputElement).value);
  }

  protected actualizarMotivoEntrada(evento: Event): void {
    const valor = (evento.target as HTMLSelectElement).value;
    if (valor === '') {
      this.motivoEntrada.set('');
      return;
    }
    if (this.esMotivoEntrada(valor)) {
      this.motivoEntrada.set(valor);
    }
  }

  protected actualizarNumeroLoteEntrada(evento: Event): void {
    this.numeroLoteEntrada.set((evento.target as HTMLInputElement).value);
  }

  protected actualizarFechaVencimientoEntrada(evento: Event): void {
    this.fechaVencimientoEntrada.set((evento.target as HTMLInputElement).value);
  }

  protected enviarEntrada(evento?: Event): void {
    evento?.preventDefault();

    if (this.guardando()) {
      return;
    }
    if (!this.formularioValidoEntrada()) {
      this.intentoEntrada.set(true);
      return;
    }

    const producto = this.productoEntrada();
    const motivo = this.motivoEntrada();
    if (!producto || motivo === '') {
      this.intentoEntrada.set(true);
      return;
    }

    const fecha = this.fechaVencimientoEntrada();
    this.guardando.set(true);

    this.api
      .registrarEntrada({
        id_producto: producto.id_producto,
        cantidad: Number(this.cantidadEntrada()),
        motivo,
        numero_lote: producto.maneja_lotes ? this.numeroLoteEntrada().trim() : null,
        fecha_vencimiento: fecha !== '' ? fecha : null,
      })
      .pipe(finalize(() => this.guardando.set(false)))
      .subscribe({
        next: (registrada) => {
          this.toasts.exito(
            'Entrada registrada',
            `Stock del lote: ${formatearNumero(registrada.stock_anterior)} → ${formatearNumero(registrada.stock_posterior)}`,
          );
          this.guardando.set(false);
          this.cerrarEntradaAhora();
          this.recargarHistorial();
        },
        error: (error: unknown) => {
          const { mensaje, detalle } = describirError(error);
          this.toasts.error(mensaje, detalle);
        },
      });
  }

  // ---------- Salida ----------

  protected abrirSalida(): void {
    if (!this.puedeSalida()) {
      return;
    }
    this.reiniciarSalida();
    this.modalSalida.set(true);
  }

  protected cerrarSalida(): void {
    if (this.guardando()) {
      return;
    }
    this.cerrarSalidaAhora();
  }

  protected cambiarProductoSalida(evento: Event): void {
    const id = this.leerId(evento);
    this.idProductoSalida.set(id);
    this.idLoteSalida.set(null);
    this.lotesSalida.set([]);
    this.errorLotesSalida.set(null);

    if (id === null) {
      this.secuenciaLotesSalida++;
      this.cargandoLotesSalida.set(false);
      return;
    }

    this.cargarLotesSalida(id);
  }

  protected cambiarLoteSalida(evento: Event): void {
    this.idLoteSalida.set(this.leerId(evento));
  }

  protected cambiarAreaSalida(evento: Event): void {
    this.idAreaSalida.set(this.leerId(evento));
  }

  protected actualizarCantidadSalida(evento: Event): void {
    this.cantidadSalida.set((evento.target as HTMLInputElement).value);
  }

  protected actualizarMotivoSalida(evento: Event): void {
    this.motivoSalida.set((evento.target as HTMLInputElement).value);
  }

  protected enviarSalida(evento?: Event): void {
    evento?.preventDefault();

    if (this.guardando()) {
      return;
    }
    if (!this.formularioValidoSalida()) {
      this.intentoSalida.set(true);
      return;
    }

    const idProducto = this.idProductoSalida();
    const idLote = this.idLoteSalida();
    const idArea = this.idAreaSalida();
    if (idProducto === null || idArea === null) {
      this.intentoSalida.set(true);
      return;
    }

    const motivo = this.motivoSalida().trim();
    this.guardando.set(true);

    this.api
      .registrarSalida({
        id_producto: idProducto,
        id_lote: idLote,
        id_area: idArea,
        cantidad: Number(this.cantidadSalida()),
        motivo,
      })
      .pipe(finalize(() => this.guardando.set(false)))
      .subscribe({
        next: (registrada) => {
          this.toasts.exito(
            'Salida registrada',
            `Lote ${registrada.numero_lote ?? registrada.id_lote}: ${formatearNumero(registrada.stock_anterior)} → ${formatearNumero(registrada.stock_posterior)}`,
          );
          this.guardando.set(false);
          this.cerrarSalidaAhora();
          this.recargarHistorial();
        },
        error: (error: unknown) => {
          const { mensaje, detalle } = describirError(error);
          this.toasts.error(mensaje, detalle);
        },
      });
  }

  // ---------- Presentación ----------

  protected etiquetaLote(lote: Lote): string {
    const numero = lote.numero_lote ?? 'Sin lote';
    const vencimiento = lote.fecha_vencimiento
      ? `vence ${formatearFecha(lote.fecha_vencimiento)}`
      : 'sin vencimiento';
    return `${numero} · ${vencimiento} · ${formatearNumero(lote.stock_actual)} disp.`;
  }

  // ---------- Internos ----------

  private cerrarEntradaAhora(): void {
    this.modalEntrada.set(false);
    this.reiniciarEntrada();
  }

  private cerrarSalidaAhora(): void {
    this.modalSalida.set(false);
    this.reiniciarSalida();
  }

  private reiniciarEntrada(): void {
    this.idProductoEntrada.set(null);
    this.cantidadEntrada.set('');
    this.motivoEntrada.set('');
    this.numeroLoteEntrada.set('');
    this.fechaVencimientoEntrada.set('');
    this.intentoEntrada.set(false);
  }

  private reiniciarSalida(): void {
    this.secuenciaLotesSalida++;
    this.idProductoSalida.set(null);
    this.idLoteSalida.set(null);
    this.idAreaSalida.set(null);
    this.cantidadSalida.set('');
    this.motivoSalida.set('');
    this.lotesSalida.set([]);
    this.cargandoLotesSalida.set(false);
    this.errorLotesSalida.set(null);
    this.intentoSalida.set(false);
  }

  private cargarLotesSalida(idProducto: number): void {
    const secuencia = ++this.secuenciaLotesSalida;
    this.cargandoLotesSalida.set(true);
    this.errorLotesSalida.set(null);

    this.api
      .cargarLotes(idProducto)
      .pipe(
        finalize(() => {
          if (secuencia === this.secuenciaLotesSalida) {
            this.cargandoLotesSalida.set(false);
          }
        }),
      )
      .subscribe({
        next: (lotes) => {
          if (secuencia !== this.secuenciaLotesSalida) {
            return;
          }
          this.lotesSalida.set(lotes.filter((lote) => lote.stock_actual > 0 && !lote.vencido));
        },
        error: (error: unknown) => {
          if (secuencia !== this.secuenciaLotesSalida) {
            return;
          }
          this.lotesSalida.set([]);
          const { mensaje, detalle } = describirError(error);
          this.errorLotesSalida.set(detalle ? `${mensaje}: ${detalle}` : mensaje);
          this.toasts.error(mensaje, detalle);
        },
      });
  }

  private cargarMotivosEntrada(): void {
    this.api.cargarMotivosEntrada().subscribe({
      next: (motivos) => {
        if (motivos.length > 0) {
          this.motivosEntrada.set(motivos as MotivoEntrada[]);
        }
      },
      error: () => undefined,
    });
  }

  private reiniciarPaginaYRecargar(): void {
    clearTimeout(this.temporizadorBusqueda);
    this.pagina.set(1);
    this.recargarHistorial();
  }

  private reiniciarPaginaConRetraso(): void {
    clearTimeout(this.temporizadorBusqueda);
    this.temporizadorBusqueda = setTimeout(() => {
      this.pagina.set(1);
      this.recargarHistorial();
    }, 300);
  }

  private filtrosServidor(): FiltrosMovimiento {
    const rangoValido = !this.rangoInvalido();
    const tipo = this.tipoFiltro();
    return {
      busqueda: this.busqueda().trim() || null,
      tipo_movimiento: tipo === 'TODOS' ? null : tipo,
      id_area: this.idAreaFiltro(),
      desde: rangoValido && this.desde() !== '' ? this.desde() : null,
      hasta: rangoValido && this.hasta() !== '' ? this.hasta() : null,
      pagina: this.pagina(),
      tamano: this.tamano,
    };
  }

  private cargarProductos(): void {
    this.api.cargarProductos().subscribe({
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        this.toasts.error(mensaje, detalle);
      },
    });
  }

  private cargarAreas(): void {
    this.api.cargarAreas().subscribe({
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        this.toasts.error(mensaje, detalle);
      },
    });
  }

  private esMotivoEntrada(valor: string): valor is MotivoEntrada {
    return this.motivosEntrada().some((motivo) => motivo === valor);
  }

  private leerId(evento: Event): number | null {
    const valor = (evento.target as HTMLSelectElement).value;
    if (valor === '') {
      return null;
    }
    const id = Number(valor);
    return Number.isInteger(id) && id > 0 ? id : null;
  }
}
