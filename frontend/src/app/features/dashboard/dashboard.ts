import { Component, computed, inject, OnInit, ChangeDetectionStrategy } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import {
  formatearFecha,
  formatearMoneda,
  formatearNumero,
  saludoSegunHora,
} from '../../core/utils/formato';
import { NAVEGACION } from '../../shared/components/layout/navegacion';

/**
 * Dashboard de bienvenida.
 *
 * Consume el resumen del inventario y las alertas, y deriva las tarjetas y
 * listas con ``computed()``. Los accesos rápidos se filtran por permisos.
 */
@Component({
  selector: 'app-dashboard',
  imports: [RouterLink],
  templateUrl: './dashboard.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './dashboard.scss',
})
export class Dashboard implements OnInit {
  protected readonly auth = inject(AuthService);
  private readonly api = inject(ApiService);

  protected readonly resumen = this.api.resumen;
  protected readonly stockBajo = this.api.stockBajo;
  protected readonly porVencer = this.api.porVencer;
  protected readonly vencidos = this.api.vencidos;

  protected readonly saludo = saludoSegunHora();
  protected readonly formatearMoneda = formatearMoneda;
  protected readonly formatearNumero = formatearNumero;
  protected readonly formatearFecha = formatearFecha;
  protected readonly fechaHoy = new Intl.DateTimeFormat('es-PE', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(new Date());

  protected readonly puedeVerAlertas = this.auth.tienePermiso('alertas:leer');

  // ---------- Métricas derivadas ----------

  protected readonly totalProductos = computed(() => this.resumen.datos()?.productos_activos ?? 0);

  protected readonly valorInventario = computed(() => this.api.valorInventario());

  protected readonly movimientosPeriodo = computed(
    () => this.resumen.datos()?.movimientos_periodo ?? 0,
  );

  protected readonly alertasStockBajo = computed(() => this.stockBajo.datos().length);
  protected readonly alertasPorVencer = computed(() => this.porVencer.datos().length);
  protected readonly alertasVencidas = computed(() => this.vencidos.datos().length);

  protected readonly totalAlertas = computed(() => this.api.totalAlertas());

  protected readonly lotesEnRiesgo = computed(
    () => this.alertasPorVencer() + this.alertasVencidas(),
  );

  protected readonly porcentajeStockBajo = computed(() => {
    const total = this.totalProductos();
    return total > 0 ? Math.min(100, Math.round((this.alertasStockBajo() / total) * 100)) : 0;
  });

  protected readonly topStockBajo = computed(() => this.stockBajo.datos().slice(0, 5));
  protected readonly topPorVencer = computed(() => this.porVencer.datos().slice(0, 5));

  protected readonly accesos = computed(() =>
    NAVEGACION.filter(
      (opcion) =>
        opcion.ruta !== '/dashboard' && (!opcion.permiso || this.auth.tienePermiso(opcion.permiso)),
    ).slice(0, 6),
  );

  ngOnInit(): void {
    if (!this.auth.tienePermiso('dashboard:leer')) {
      return;
    }

    this.api.cargarResumen().subscribe({ error: () => undefined });

    if (this.puedeVerAlertas) {
      this.api.cargarStockBajo().subscribe({ error: () => undefined });
      this.api.cargarPorVencer(30).subscribe({ error: () => undefined });
      this.api.cargarVencidos().subscribe({ error: () => undefined });
    }
  }
}
