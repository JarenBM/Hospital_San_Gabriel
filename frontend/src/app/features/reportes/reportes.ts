import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { finalize } from 'rxjs';
import type { MayorSalida, MovimientoListado, ProductoListado } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import {
  fechaHaceDiasISO,
  fechaHoyISO,
  formatearFechaHora,
  formatearNumero,
} from '../../core/utils/formato';

type PestanaReportes = 'kardex' | 'mayores';

/** Valor de un ``input`` o ``select`` nativo a partir del evento del DOM. */
function valorCampo(evento: Event): string {
  return (evento.target as HTMLInputElement | HTMLSelectElement).value;
}

/** Valida que ambas fechas existan y que el rango sea coherente. */
function validarRango(desde: string, hasta: string): string | null {
  if (!desde || !hasta) {
    return 'Indique la fecha inicial y la fecha final.';
  }
  if (desde > hasta) {
    return 'La fecha inicial no puede ser posterior a la fecha final.';
  }
  return null;
}

/**
 * Reportes de inventario (solo lectura).
 *
 * - Kardex: movimientos de un producto en un rango de fechas. El resultado se
 *   guarda localmente para no compartir el recurso ``movimientos`` con la
 *   página de movimientos.
 * - Mayores salidas: ranking de productos por unidades despachadas.
 */
@Component({
  selector: 'app-reportes',
  templateUrl: './reportes.html',
  styleUrl: './reportes.scss',
})
export class Reportes implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly toasts = inject(ToastService);

  protected readonly formatearFechaHora = formatearFechaHora;
  protected readonly formatearNumero = formatearNumero;

  protected readonly pestana = signal<PestanaReportes>('kardex');

  // ---------- Kardex ----------

  protected readonly productos = this.api.productos;

  protected readonly idProducto = signal<number | null>(null);
  protected readonly desdeKardex = signal(fechaHaceDiasISO(30));
  protected readonly hastaKardex = signal(fechaHoyISO());
  protected readonly kardex = signal<MovimientoListado[]>([]);
  protected readonly cargandoKardex = signal(false);
  protected readonly errorKardex = signal<string | null>(null);
  protected readonly consultadoKardex = signal(false);
  protected readonly intentoKardex = signal(false);
  protected readonly filtroKardex = signal('');

  // ---------- Mayores salidas ----------

  protected readonly desdeMayores = signal(fechaHaceDiasISO(30));
  protected readonly hastaMayores = signal(fechaHoyISO());
  protected readonly top = signal(10);
  protected readonly mayores = signal<MayorSalida[]>([]);
  protected readonly cargandoMayores = signal(false);
  protected readonly errorMayores = signal<string | null>(null);
  protected readonly intentoMayores = signal(false);

  // ---------- Derivados ----------

  protected readonly productosDisponibles = computed<ProductoListado[]>(() =>
    [...this.productos.datos()].sort((a, b) => a.nombre.localeCompare(b.nombre, 'es')),
  );

  protected readonly productoSeleccionado = computed<ProductoListado | null>(() => {
    const id = this.idProducto();
    if (id === null) {
      return null;
    }
    return this.productos.datos().find((producto) => producto.id_producto === id) ?? null;
  });

  protected readonly errorProducto = computed<string | null>(() =>
    this.idProducto() === null ? 'Seleccione un producto para consultar el kardex.' : null,
  );

  protected readonly errorRangoKardex = computed<string | null>(() =>
    validarRango(this.desdeKardex(), this.hastaKardex()),
  );

  protected readonly formularioKardexValido = computed(
    () => this.errorProducto() === null && this.errorRangoKardex() === null,
  );

  protected readonly errorRangoMayores = computed<string | null>(() =>
    validarRango(this.desdeMayores(), this.hastaMayores()),
  );

  protected readonly formularioMayoresValido = computed(
    () => this.errorRangoMayores() === null,
  );

  protected readonly resumenKardex = computed(() => {
    let entradas = 0;
    let salidas = 0;

    for (const movimiento of this.kardex()) {
      if (movimiento.tipo_movimiento === 'ENTRADA') {
        entradas += movimiento.cantidad;
      } else {
        salidas += movimiento.cantidad;
      }
    }

    return { entradas, salidas, movimientos: this.kardex().length };
  });

  protected readonly kardexFiltrado = computed<MovimientoListado[]>(() => {
    const termino = this.filtroKardex().trim().toLowerCase();
    if (!termino) {
      return this.kardex();
    }

    return this.kardex().filter((movimiento) =>
      [
        movimiento.producto,
        movimiento.codigo,
        movimiento.numero_lote ?? '',
        movimiento.area ?? '',
        movimiento.usuario,
        movimiento.motivo,
      ].some((valor) => valor.toLowerCase().includes(termino)),
    );
  });

  protected readonly maxSalidas = computed(() =>
    this.mayores().reduce((maximo, item) => Math.max(maximo, item.total_salidas), 0),
  );

  ngOnInit(): void {
    if (!this.auth.tienePermiso('reportes:leer')) {
      return;
    }

    this.recargarProductos();
    this.ejecutarMayores(false);
  }

  protected seleccionarPestana(pestana: PestanaReportes): void {
    this.pestana.set(pestana);
  }

  // ---------- Kardex ----------

  protected recargarProductos(): void {
    this.api.cargarProductos().subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
  }

  protected actualizarProducto(evento: Event): void {
    const valor = valorCampo(evento);
    if (valor === '') {
      this.idProducto.set(null);
      return;
    }
    const id = Number(valor);
    this.idProducto.set(Number.isFinite(id) ? id : null);
  }

  protected actualizarDesdeKardex(evento: Event): void {
    this.desdeKardex.set(valorCampo(evento));
  }

  protected actualizarHastaKardex(evento: Event): void {
    this.hastaKardex.set(valorCampo(evento));
  }

  protected actualizarFiltroKardex(evento: Event): void {
    this.filtroKardex.set(valorCampo(evento));
  }

  protected consultarKardex(): void {
    this.intentoKardex.set(true);

    if (!this.formularioKardexValido() || this.cargandoKardex()) {
      return;
    }

    const idProducto = this.idProducto();
    if (idProducto === null) {
      return;
    }

    this.cargandoKardex.set(true);
    this.errorKardex.set(null);

    this.api
      .consultarMovimientos({
        id_producto: idProducto,
        desde: this.desdeKardex(),
        hasta: this.hastaKardex(),
      })
      .pipe(finalize(() => this.cargandoKardex.set(false)))
      .subscribe({
        next: (movimientos) => {
          this.kardex.set(movimientos);
          this.consultadoKardex.set(true);
          this.toasts.info(
            'Kardex consultado',
            `${movimientos.length} movimientos de ${
              this.productoSeleccionado()?.nombre ?? 'el producto'
            }.`,
          );
        },
        error: (error: unknown) => {
          const { mensaje, detalle } = describirError(error);
          this.errorKardex.set(detalle ? `${mensaje}: ${detalle}` : mensaje);
          this.toasts.error(mensaje, detalle);
        },
      });
  }

  // ---------- Mayores salidas ----------

  protected actualizarDesdeMayores(evento: Event): void {
    this.desdeMayores.set(valorCampo(evento));
  }

  protected actualizarHastaMayores(evento: Event): void {
    this.hastaMayores.set(valorCampo(evento));
  }

  protected actualizarTop(evento: Event): void {
    const valor = Number(valorCampo(evento));
    if (valor === 10 || valor === 25 || valor === 50) {
      this.top.set(valor);
    }
  }

  protected consultarMayores(): void {
    this.ejecutarMayores(true);
  }

  protected porcentaje(total: number): number {
    const maximo = this.maxSalidas();
    if (maximo <= 0) {
      return 0;
    }
    return Math.min(100, Math.round((total / maximo) * 100));
  }

  private ejecutarMayores(notificar: boolean): void {
    this.intentoMayores.set(true);

    if (!this.formularioMayoresValido() || this.cargandoMayores()) {
      return;
    }

    this.cargandoMayores.set(true);
    this.errorMayores.set(null);

    this.api
      .cargarMayoresSalidas({
        desde: this.desdeMayores(),
        hasta: this.hastaMayores(),
        top: this.top(),
      })
      .pipe(finalize(() => this.cargandoMayores.set(false)))
      .subscribe({
        next: (datos) => {
          this.mayores.set(datos);
          if (notificar) {
            this.toasts.exito(
              'Reporte actualizado',
              `${datos.length} productos en el ranking de salidas.`,
            );
          }
        },
        error: (error: unknown) => {
          const { mensaje, detalle } = describirError(error);
          this.errorMayores.set(detalle ? `${mensaje}: ${detalle}` : mensaje);
          this.toasts.error(mensaje, detalle);
        },
      });
  }

  private notificarError(error: unknown): void {
    const { mensaje, detalle } = describirError(error);
    this.toasts.error(mensaje, detalle);
  }
}
