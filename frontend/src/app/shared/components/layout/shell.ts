import {
  Component,
  computed,
  HostListener,
  inject,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';
import type { TipoNotificacion } from '../../../core/services/notificacion.service';
import { NotificacionService } from '../../../core/services/notificacion.service';
import { AuthService } from '../../../core/services/auth.service';
import { GRUPOS_NAVEGACION, NAVEGACION, opcionPorUrl } from './navegacion';

/**
 * Layout principal de la aplicación autenticada.
 *
 * Navbar + sidebar responsive. Las opciones del menú se calculan con
 * ``computed()`` a partir de los permisos efectivos del usuario, de modo que
 * desaparecen en cuanto cambia la sesión.
 */
@Component({
  selector: 'app-shell',
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './shell.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './shell.scss',
})
export class Shell {
  protected readonly auth = inject(AuthService);
  protected readonly notificaciones = inject(NotificacionService);
  private readonly router = inject(Router);

  protected readonly menuAbierto = signal(false);
  protected readonly perfilAbierto = signal(false);
  protected readonly notificacionesAbiertas = signal(false);
  protected readonly anio = new Date().getFullYear();

  private readonly navegacion = toSignal(
    this.router.events.pipe(
      filter((evento): evento is NavigationEnd => evento instanceof NavigationEnd),
    ),
    { initialValue: null },
  );

  protected readonly opciones = computed(() =>
    NAVEGACION.filter((opcion) => !opcion.permiso || this.auth.tienePermiso(opcion.permiso)),
  );

  protected readonly grupos = computed(() =>
    GRUPOS_NAVEGACION.map((titulo) => ({
      titulo,
      opciones: this.opciones().filter((opcion) => opcion.grupo === titulo),
    })).filter((grupo) => grupo.opciones.length > 0),
  );

  protected readonly tituloPagina = computed(() => {
    this.navegacion();
    return opcionPorUrl(this.router.url)?.etiqueta ?? 'SIGIH';
  });

  protected readonly descripcionPagina = computed(() => {
    this.navegacion();
    return (
      opcionPorUrl(this.router.url)?.descripcion ?? 'Sistema de Gestión de Inventario Hospitalario'
    );
  });

  private readonly iconosNotificacion: Record<TipoNotificacion, string> = {
    exito: 'bi-check-circle',
    error: 'bi-x-circle',
    advertencia: 'bi-exclamation-triangle',
    info: 'bi-info-circle',
  };

  constructor() {
    this.router.events
      .pipe(
        filter((evento) => evento instanceof NavigationEnd),
        takeUntilDestroyed(),
      )
      .subscribe(() => this.cerrarPaneles());
  }

  protected iconoNotificacion(tipo: TipoNotificacion): string {
    return this.iconosNotificacion[tipo];
  }

  protected alternarNotificaciones(): void {
    this.notificacionesAbiertas.update((abierto) => !abierto);
    this.perfilAbierto.set(false);
  }

  protected alternarPerfil(): void {
    this.perfilAbierto.update((abierto) => !abierto);
    this.notificacionesAbiertas.set(false);
  }

  protected cerrarSesion(): void {
    this.perfilAbierto.set(false);
    this.auth.logout();
  }

  protected descartarNotificacion(id: number): void {
    this.notificaciones.descartar(id);
  }

  /** Cierra los desplegables al hacer clic fuera de ellos. */
  @HostListener('document:click')
  protected cerrarPaneles(): void {
    this.perfilAbierto.set(false);
    this.notificacionesAbiertas.set(false);
  }
}
