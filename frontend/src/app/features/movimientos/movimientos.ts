import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { finalize } from 'rxjs';
import type { Lote, MotivoEntrada, TipoMovimiento } from '../../models';
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
  idLote: string | null;
  idArea: string | null;
  cantidad: string | null;
  motivo: string | null;
}

/**
 * Historial de movimientos y registro de entradas y salidas.
 *
 * Los filtros se aplican localmente sobre la lista que entrega la API. El
 * formulario de entrada solo pide lote y vencimiento cuando el producto los
 * maneja; el de salida solo ofrece lotes vigentes con stock disponible.
 */
@Component({
  selector: 'app-movimientos',
  imports: [Modal],
  templateUrl: './movimientos.html',
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

  protected readonly puedeLeer = computed(() =>
    this.auth.tienePermiso('movimientos:leer'),
  );
  protected readonly puedeEntrada = computed(() =>
    this.auth.tienePermiso('movimientos:entrada'),
  );
  protected readonly puedeSalida = computed(() =>
    this.auth.tienePermiso('movimientos:salida'),
  );

  protected readonly formatearFecha = formatearFecha;
  protected readonly formatearFechaHora = formatearFechaHora;
  protected readonly formatearNumero = formatearNumero;
  protected readonly motivosEntrada = MOTIVOS_ENTRADA;
  protected readonly tiposFiltro: readonly FiltroTipo[] = [
    'TODOS',
    'ENTRADA',
    'SALIDA',
  ];
  protected readonly hoy = fechaHoyISO();

  // ---------- Filtros ----------

  protected readonly busqueda = signal('');
  protected readonly tipoFiltro = signal<FiltroTipo>('TODOS');
  protected readonly idAreaFiltro = signal<number | null>(null);
  protected readonly desde = signal('');
  protected readonly hasta = signal('');

  protected readonly rangoInvalido = computed(
    () =>
      this.desde() !== '' && this.hasta() !== '' && this.desde() > this.hasta(),
  );

  protected readonly areaFiltro = computed(() => {
    const id = this.idAreaFiltro();
    if (id === null) {
      return null;
    }
    return this.areas().find((area) => area.id_area === id) ?? null;
  });

  protected readonly totalMovimientos = computed(
    () => this.movimientos.datos().length,
  );

  protected readonly movimientosFiltrados = computed(() => {
    const termino = this.busqueda().trim().toLowerCase();
    const tipo = this.tipoFiltro();
    const area = this.areaFiltro();
    const desde = this.desde();
    const hasta = this.hasta();
    const rangoValido = !this.rangoInvalido();

    return this.movimientos.datos().filter((movimiento) => {
      if (tipo !== 'TODOS' && movimiento.tipo_movimiento !== tipo) {
        return false;
      }

      if (area !== null && movimiento.area !== area.nombre) {
        return false;
      }

      // Un rango inválido no se aplica: se avisa al usuario y se dejan ver
      // los movimientos que cumplen el resto de los filtros.
      if (rangoValido) {
        const fecha = movimiento.fecha_movimiento.slice(0, 10);
        if (desde !== '' && fecha < desde) {
          return false;
        }
        if (hasta !== '' && fecha > hasta) {
          return false;
        }
      }

      if (termino !== '') {
        const texto = [
          movimiento.producto,
          movimiento.codigo,
          movimiento.numero_lote ?? '',
          movimiento.motivo,
          movimiento.usuario,
        ]
          .join(' ')
          .toLowerCase();
        if (!texto.includes(termino)) {
          return false;
        }
      }

      return true;
    });
  });

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

  protected readonly stockMaximo = computed(
    () => this.loteSalida()?.stock_actual ?? 0,
  );

  protected readonly erroresSalida = computed<ErroresSalida>(() => {
    const producto = this.productoSalida();
    const lote = this.loteSalida();
    const area = this.areasActivas().find(
      (item) => item.id_area === this.idAreaSalida(),
    );
    const cantidadTexto = this.cantidadSalida().trim();
    const cantidad = Number(cantidadTexto);
    const motivo = this.motivoSalida().trim();

    let errorCantidad: string | null = null;
    if (cantidadTexto === '') {
      errorCantidad = 'Ingrese una cantidad.';
    } else if (!Number.isInteger(cantidad) || cantidad <= 0) {
      errorCantidad = 'La cantidad debe ser un entero mayor que 0.';
    } else if (lote !== null && cantidad > lote.stock_actual) {
      errorCantidad = `La cantidad no puede superar el stock disponible (${formatearNumero(lote.stock_actual)}).`;
    }

    return {
      idProducto: producto ? null : 'Seleccione un producto.',
      idLote: lote ? null : 'Seleccione un lote.',
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
  }

  // ---------- Filtros ----------

  protected actualizarBusqueda(evento: Event): void {
    this.busqueda.set((evento.target as HTMLInputElement).value);
  }

  protected actualizarTipoFiltro(evento: Event): void {
    const valor = (evento.target as HTMLSelectElement).value;
    if (valor === 'TODOS' || valor === 'ENTRADA' || valor === 'SALIDA') {
      this.tipoFiltro.set(valor);
    }
  }

  protected actualizarAreaFiltro(evento: Event): void {
    this.idAreaFiltro.set(this.leerId(evento));
  }

  protected actualizarDesde(evento: Event): void {
    this.desde.set((evento.target as HTMLInputElement).value);
  }

  protected actualizarHasta(evento: Event): void {
    this.hasta.set((evento.target as HTMLInputElement).value);
  }

  protected recargarHistorial(): void {
    if (!this.puedeLeer()) {
      return;
    }
    this.api.cargarMovimientos().subscribe({
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
        numero_lote: producto.maneja_lotes
          ? this.numeroLoteEntrada().trim()
          : null,
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
    if (idProducto === null || idLote === null || idArea === null) {
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
            `Stock del lote: ${formatearNumero(registrada.stock_anterior)} → ${formatearNumero(registrada.stock_posterior)}`,
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
          this.lotesSalida.set(
            lotes.filter((lote) => lote.stock_actual > 0 && !lote.vencido),
          );
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
    return MOTIVOS_ENTRADA.some((motivo) => motivo === valor);
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
