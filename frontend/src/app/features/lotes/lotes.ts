import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import { finalize } from 'rxjs';
import type { Lote } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { formatearFecha, formatearFechaHora, formatearNumero } from '../../core/utils/formato';

/**
 * Consulta de lotes por producto.
 *
 * No existe CRUD de lotes: esta vista solo lee el stock y los vencimientos.
 * Las existencias cambian exclusivamente mediante entradas y salidas.
 */
@Component({
  selector: 'app-lotes',
  templateUrl: './lotes.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './lotes.scss',
})
export class Lotes implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly toasts = inject(ToastService);

  protected readonly productos = this.api.productosActivos;
  protected readonly cargandoProductos = this.api.productos.cargando;
  protected readonly puedeLeer = computed(() => this.auth.tienePermiso('lotes:leer'));

  protected readonly idProducto = signal<number | null>(null);
  protected readonly lotes = signal<Lote[]>([]);
  protected readonly cargandoLotes = signal(false);
  protected readonly errorLotes = signal<string | null>(null);
  protected readonly errorProductos = signal<string | null>(null);

  protected readonly formatearFecha = formatearFecha;
  protected readonly formatearFechaHora = formatearFechaHora;
  protected readonly formatearNumero = formatearNumero;

  protected readonly productoSeleccionado = computed(() => {
    const id = this.idProducto();
    if (id === null) {
      return null;
    }
    return this.productos().find((producto) => producto.id_producto === id) ?? null;
  });

  protected readonly totalLotes = computed(() => this.lotes().length);

  protected readonly stockTotal = computed(() =>
    this.lotes().reduce((total, lote) => total + lote.stock_actual, 0),
  );

  private secuenciaLotes = 0;

  ngOnInit(): void {
    if (!this.puedeLeer()) {
      return;
    }
    this.cargarProductos();
  }

  protected seleccionarProducto(evento: Event): void {
    const id = this.leerId(evento);
    this.idProducto.set(id);
    this.lotes.set([]);
    this.errorLotes.set(null);

    if (id !== null) {
      this.cargarLotes(id);
    }
  }

  protected reintentarProductos(): void {
    this.cargarProductos();
  }

  protected reintentarLotes(): void {
    const id = this.idProducto();
    if (id !== null) {
      this.cargarLotes(id);
    }
  }

  private cargarProductos(): void {
    this.errorProductos.set(null);

    this.api.cargarProductos().subscribe({
      next: () => this.errorProductos.set(null),
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        this.errorProductos.set(detalle ? `${mensaje}: ${detalle}` : mensaje);
        this.toasts.error(mensaje, detalle);
      },
    });
  }

  private cargarLotes(idProducto: number): void {
    const secuencia = ++this.secuenciaLotes;
    this.cargandoLotes.set(true);
    this.errorLotes.set(null);

    this.api
      .cargarLotes(idProducto)
      .pipe(
        finalize(() => {
          if (secuencia === this.secuenciaLotes) {
            this.cargandoLotes.set(false);
          }
        }),
      )
      .subscribe({
        next: (lotes) => {
          if (secuencia !== this.secuenciaLotes) {
            return;
          }
          this.lotes.set(lotes);
        },
        error: (error: unknown) => {
          if (secuencia !== this.secuenciaLotes) {
            return;
          }
          this.lotes.set([]);
          const { mensaje, detalle } = describirError(error);
          this.errorLotes.set(detalle ? `${mensaje}: ${detalle}` : mensaje);
          this.toasts.error(mensaje, detalle);
        },
      });
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
