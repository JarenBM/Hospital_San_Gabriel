import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import { finalize } from 'rxjs';
import type { Area } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ConfirmacionService } from '../../core/services/confirmacion.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { Modal } from '../../shared/components/modal/modal';

type FiltroEstado = 'todos' | 'activos' | 'inactivos';

/** Valor de un ``input`` o ``select`` nativo a partir del evento del DOM. */
function valorCampo(evento: Event): string {
  return (evento.target as HTMLInputElement | HTMLSelectElement).value;
}

/**
 * Mantenimiento de áreas hospitalarias.
 *
 * Lista todas las áreas (incluidas las inactivas), permite filtrarlas por
 * nombre y estado, y ofrece alta, edición, desactivación y reactivación.
 * Las acciones de escritura solo se muestran con ``areas:escribir``.
 */
@Component({
  selector: 'app-areas',
  imports: [Modal],
  templateUrl: './areas.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './areas.scss',
})
export class Areas implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly confirmacion = inject(ConfirmacionService);
  private readonly toasts = inject(ToastService);

  protected readonly areas = this.api.areas;
  protected readonly puedeEscribir = computed(() => this.auth.tienePermiso('areas:escribir'));

  protected readonly busqueda = signal('');
  protected readonly filtroEstado = signal<FiltroEstado>('todos');

  protected readonly areasFiltradas = computed<Area[]>(() => {
    const termino = this.busqueda().trim().toLowerCase();
    const estado = this.filtroEstado();

    return this.areas.datos().filter((area) => {
      const coincideNombre = !termino || area.nombre.toLowerCase().includes(termino);
      const coincideEstado =
        estado === 'todos' || (estado === 'activos' ? area.activo : !area.activo);
      return coincideNombre && coincideEstado;
    });
  });

  protected readonly totalActivas = computed(
    () => this.areas.datos().filter((area) => area.activo).length,
  );

  protected readonly hayFiltro = computed(
    () => this.busqueda().trim() !== '' || this.filtroEstado() !== 'todos',
  );

  protected readonly modalAbierto = signal(false);
  protected readonly editando = signal<Area | null>(null);
  protected readonly nombre = signal('');
  protected readonly nombreTocado = signal(false);
  protected readonly guardando = signal(false);
  protected readonly procesando = signal<number | null>(null);

  protected readonly tituloModal = computed(() => (this.editando() ? 'Editar área' : 'Nueva área'));

  protected readonly subtituloModal = computed(() =>
    this.editando()
      ? 'Actualice el nombre del área seleccionada.'
      : 'Registre una nueva área hospitalaria.',
  );

  protected readonly errorNombre = computed<string | null>(() => {
    const nombre = this.nombre().trim();
    if (!nombre) {
      return 'El nombre es obligatorio.';
    }
    if (nombre.length > 100) {
      return 'El nombre no puede superar los 100 caracteres.';
    }
    return null;
  });

  protected readonly formularioValido = computed(() => this.errorNombre() === null);

  ngOnInit(): void {
    if (!this.auth.tienePermiso('areas:leer')) {
      return;
    }
    this.recargar();
  }

  protected recargar(): void {
    this.api.cargarAreas().subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
  }

  protected actualizarBusqueda(evento: Event): void {
    this.busqueda.set(valorCampo(evento));
  }

  protected actualizarFiltroEstado(evento: Event): void {
    const valor = valorCampo(evento);
    if (valor === 'todos' || valor === 'activos' || valor === 'inactivos') {
      this.filtroEstado.set(valor);
    }
  }

  protected abrirAlta(): void {
    if (!this.puedeEscribir()) {
      return;
    }
    this.editando.set(null);
    this.nombre.set('');
    this.nombreTocado.set(false);
    this.modalAbierto.set(true);
  }

  protected abrirEdicion(area: Area): void {
    if (!this.puedeEscribir()) {
      return;
    }
    this.editando.set(area);
    this.nombre.set(area.nombre);
    this.nombreTocado.set(false);
    this.modalAbierto.set(true);
  }

  protected cerrarModal(): void {
    if (this.guardando()) {
      return;
    }
    this.modalAbierto.set(false);
  }

  protected actualizarNombre(evento: Event): void {
    this.nombre.set(valorCampo(evento));
    this.nombreTocado.set(true);
  }

  protected marcarNombreTocado(): void {
    this.nombreTocado.set(true);
  }

  protected guardar(): void {
    this.nombreTocado.set(true);

    if (!this.formularioValido() || this.guardando() || !this.puedeEscribir()) {
      return;
    }

    const area = this.editando();
    const nombre = this.nombre().trim();

    this.guardando.set(true);
    const peticion = area
      ? this.api.actualizarArea(area.id_area, { nombre })
      : this.api.crearArea({ nombre });

    peticion.pipe(finalize(() => this.guardando.set(false))).subscribe({
      next: () => {
        this.toasts.exito(area ? 'Área actualizada' : 'Área creada', `Se guardó «${nombre}».`);
        this.modalAbierto.set(false);
      },
      error: (error: unknown) => this.notificarError(error),
    });
  }

  protected async desactivar(area: Area): Promise<void> {
    if (!this.puedeEscribir() || this.procesando() !== null) {
      return;
    }

    const confirmado = await this.confirmacion.confirmar({
      titulo: 'Desactivar área',
      mensaje: `¿Desea desactivar el área «${area.nombre}»?`,
      detalle: 'Dejará de estar disponible para registrar nuevas salidas de inventario.',
      textoConfirmar: 'Desactivar',
      variante: 'peligro',
      icono: 'bi-hospital',
    });

    if (!confirmado) {
      return;
    }

    this.procesando.set(area.id_area);
    this.api
      .desactivarArea(area.id_area)
      .pipe(finalize(() => this.procesando.set(null)))
      .subscribe({
        next: () => this.toasts.exito('Área desactivada', `«${area.nombre}» quedó inactiva.`),
        error: (error: unknown) => this.notificarError(error),
      });
  }

  protected reactivar(area: Area): void {
    if (!this.puedeEscribir() || this.procesando() !== null) {
      return;
    }

    this.procesando.set(area.id_area);
    this.api
      .actualizarArea(area.id_area, { nombre: area.nombre, activo: true })
      .pipe(finalize(() => this.procesando.set(null)))
      .subscribe({
        next: () => this.toasts.exito('Área reactivada', `«${area.nombre}» volvió a estar activa.`),
        error: (error: unknown) => this.notificarError(error),
      });
  }

  private notificarError(error: unknown): void {
    const { mensaje, detalle } = describirError(error);
    this.toasts.error(mensaje, detalle);
  }
}
