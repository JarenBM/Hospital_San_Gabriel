import { Component, computed, inject, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import {
  formatearMoneda,
  formatearNumero,
  saludoSegunHora,
} from '../../core/utils/formato';
import { NAVEGACION } from '../../shared/components/layout/navegacion';

/**
 * Dashboard de bienvenida.
 *
 * Consume ``GET /api/dashboard/resumen`` y pinta el estado del inventario con
 * los signals de ``ApiService``. Los accesos rápidos se filtran por permisos.
 */
@Component({
  selector: 'app-dashboard',
  imports: [RouterLink],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
})
export class Dashboard implements OnInit {
  protected readonly auth = inject(AuthService);
  private readonly api = inject(ApiService);

  protected readonly resumen = this.api.resumen;
  protected readonly saludo = saludoSegunHora();
  protected readonly formatearMoneda = formatearMoneda;
  protected readonly formatearNumero = formatearNumero;
  protected readonly fechaHoy = new Intl.DateTimeFormat('es-PE', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(new Date());

  protected readonly accesos = computed(() =>
    NAVEGACION.filter(
      (opcion) =>
        opcion.ruta !== '/dashboard' &&
        (!opcion.permiso || this.auth.tienePermiso(opcion.permiso)),
    ).slice(0, 6),
  );

  ngOnInit(): void {
    if (!this.auth.tienePermiso('dashboard:leer')) {
      return;
    }
    this.api.cargarResumen().subscribe({ error: () => undefined });
  }
}
