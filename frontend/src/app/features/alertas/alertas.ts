import { Component, computed, inject, OnInit, signal } from '@angular/core';
import type { LoteAlerta, ProductoStockBajo } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { formatearFecha, formatearNumero } from '../../core/utils/formato';

type PestanaAlertas = 'stock-bajo' | 'por-vencer' | 'vencidos';

/** Valor de un ``input`` o ``select`` nativo a partir del evento del DOM. */
function valorCampo(evento: Event): string {
  return (evento.target as HTMLInputElement | HTMLSelectElement).value;
}

/**
 * Panel de alertas de inventario (solo lectura).
 *
 * Carga stock bajo, lotes por vencer y lotes vencidos en paralelo al iniciar.
 * Cada pestaña ofrece búsqueda local por producto, código o lote y muestra los
 * errores de su recurso sin bloquear las demás consultas.
 */
@Component({
  selector: 'app-alertas',
  templateUrl: './alertas.html',
  styleUrl: './alertas.scss',
})
export class Alertas implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly toasts = inject(ToastService);

  protected readonly formatearFecha = formatearFecha;
  protected readonly formatearNumero = formatearNumero;

  protected readonly stockBajo = this.api.stockBajo;
  protected readonly porVencer = this.api.porVencer;
  protected readonly vencidos = this.api.vencidos;

  protected readonly pestana = signal<PestanaAlertas>('stock-bajo');
  protected readonly busqueda = signal('');
  protected readonly dias = signal(30);

  protected readonly totalStockBajo = computed(() => this.stockBajo.datos().length);
  protected readonly totalPorVencer = computed(() => this.porVencer.datos().length);
  protected readonly totalVencidos = computed(() => this.vencidos.datos().length);

  protected readonly valorDias = computed(() =>
    Number.isNaN(this.dias()) ? '' : String(this.dias()),
  );

  protected readonly errorDias = computed<string | null>(() => {
    const dias = this.dias();
    if (!Number.isFinite(dias) || !Number.isInteger(dias)) {
      return 'Indique un número entero de días.';
    }
    if (dias < 0 || dias > 3650) {
      return 'El rango permitido es de 0 a 3650 días.';
    }
    return null;
  });

  protected readonly formularioValido = computed(() => this.errorDias() === null);

  protected readonly placeholderBusqueda = computed(() =>
    this.pestana() === 'stock-bajo' ? 'Producto o código' : 'Producto, código o lote',
  );

  private readonly termino = computed(() => this.busqueda().trim().toLowerCase());

  protected readonly stockBajoFiltrado = computed<ProductoStockBajo[]>(() => {
    const termino = this.termino();
    if (!termino) {
      return this.stockBajo.datos();
    }
    return this.stockBajo
      .datos()
      .filter(
        (item) =>
          item.nombre.toLowerCase().includes(termino) ||
          item.codigo.toLowerCase().includes(termino),
      );
  });

  protected readonly porVencerFiltrado = computed<LoteAlerta[]>(() => {
    const termino = this.termino();
    if (!termino) {
      return this.porVencer.datos();
    }
    return this.porVencer.datos().filter((lote) => this.coincideLote(lote, termino));
  });

  protected readonly vencidosFiltrado = computed<LoteAlerta[]>(() => {
    const termino = this.termino();
    if (!termino) {
      return this.vencidos.datos();
    }
    return this.vencidos.datos().filter((lote) => this.coincideLote(lote, termino));
  });

  protected readonly hayBusqueda = computed(() => this.termino() !== '');

  ngOnInit(): void {
    if (!this.auth.tienePermiso('alertas:leer')) {
      return;
    }

    this.recargarStockBajo();
    this.recargarPorVencer();
    this.recargarVencidos();
  }

  protected seleccionarPestana(pestana: PestanaAlertas): void {
    this.pestana.set(pestana);
  }

  protected actualizarBusqueda(evento: Event): void {
    this.busqueda.set(valorCampo(evento));
  }

  protected actualizarDias(evento: Event): void {
    const valor = valorCampo(evento).trim();
    this.dias.set(valor === '' ? Number.NaN : Number(valor));
  }

  protected recargarStockBajo(): void {
    this.api.cargarStockBajo().subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
  }

  protected recargarVencidos(): void {
    this.api.cargarVencidos().subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
  }

  protected recargarPorVencer(): void {
    this.api.cargarPorVencer(this.dias()).subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
  }

  protected actualizarPorVencer(): void {
    if (!this.formularioValido() || this.porVencer.cargando()) {
      return;
    }

    this.api.cargarPorVencer(this.dias()).subscribe({
      next: (lotes) =>
        this.toasts.exito(
          'Alerta actualizada',
          `${lotes.length} lotes por vencer en los próximos ${this.dias()} días.`,
        ),
      error: (error: unknown) => this.notificarError(error),
    });
  }

  private coincideLote(lote: LoteAlerta, termino: string): boolean {
    return (
      lote.nombre.toLowerCase().includes(termino) ||
      lote.codigo.toLowerCase().includes(termino) ||
      (lote.numero_lote ?? '').toLowerCase().includes(termino)
    );
  }

  private notificarError(error: unknown): void {
    const { mensaje, detalle } = describirError(error);
    this.toasts.error(mensaje, detalle);
  }
}
