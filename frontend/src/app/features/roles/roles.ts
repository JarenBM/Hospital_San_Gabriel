import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { PERMISOS_CATALOGO } from '../../models';
import type { Permiso, Rol, RolActualizar, RolCrear } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ConfirmacionService } from '../../core/services/confirmacion.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { Modal } from '../../shared/components/modal/modal';

type FiltroEstado = 'todos' | 'activos' | 'inactivos';

interface GrupoPermisos {
  modulo: string;
  permisos: Permiso[];
}

/**
 * Gestión de roles y su matriz de permisos.
 *
 * Carga todos los roles (incluidos los inactivos) y el catálogo de permisos.
 * La sincronización se envía como códigos ``modulo:accion`` al backend.
 */
@Component({
  selector: 'app-roles',
  imports: [Modal],
  templateUrl: './roles.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './roles.scss',
})
export class Roles implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly toasts = inject(ToastService);
  private readonly confirmacion = inject(ConfirmacionService);

  protected readonly roles = this.api.rolesCatalogo;
  protected readonly permisosCatalogo = this.api.permisosCatalogo;

  protected readonly puedeGestionar = computed(() => this.auth.tienePermiso('roles:gestionar'));

  // ---------- Filtros ----------

  protected readonly busqueda = signal('');
  protected readonly filtroEstado = signal<FiltroEstado>('todos');

  protected readonly rolesFiltrados = computed(() => {
    const termino = this.busqueda().trim().toLowerCase();
    const estado = this.filtroEstado();

    return this.roles.datos().filter((rol) => {
      if (termino && !`${rol.nombre} ${rol.descripcion ?? ''}`.toLowerCase().includes(termino)) {
        return false;
      }
      if (estado === 'activos' && !rol.activo) {
        return false;
      }
      if (estado === 'inactivos' && rol.activo) {
        return false;
      }
      return true;
    });
  });

  // ---------- Modal de alta / edición ----------

  protected readonly modalFormulario = signal(false);
  protected readonly rolEditando = signal<Rol | null>(null);
  protected readonly nombre = signal('');
  protected readonly descripcion = signal('');
  protected readonly intentado = signal(false);
  protected readonly guardando = signal(false);

  protected readonly tituloModal = computed(() =>
    this.rolEditando() ? 'Editar rol' : 'Nuevo rol',
  );

  protected readonly errorNombre = computed(() => {
    const valor = this.nombre().trim();
    if (!valor) {
      return 'El nombre es obligatorio.';
    }
    if (valor.length > 50) {
      return 'El nombre no debe superar los 50 caracteres.';
    }
    return '';
  });

  protected readonly errorDescripcion = computed(() => {
    if (this.descripcion().trim().length > 255) {
      return 'La descripción no debe superar los 255 caracteres.';
    }
    return '';
  });

  protected readonly formularioValido = computed(
    () => !this.errorNombre() && !this.errorDescripcion(),
  );

  // ---------- Modal de permisos ----------

  protected readonly modalPermisos = signal(false);
  protected readonly rolPermisos = signal<Rol | null>(null);
  protected readonly seleccionados = signal<Set<string>>(new Set());
  protected readonly cargandoPermisos = signal(false);
  protected readonly guardandoPermisos = signal(false);

  protected readonly permisosDisponibles = computed<Permiso[]>(() => {
    const catalogo = this.permisosCatalogo.datos();
    if (catalogo.length > 0) {
      return catalogo;
    }
    return PERMISOS_CATALOGO.map((permiso, indice) => ({
      id_permiso: -(indice + 1),
      codigo: permiso.codigo,
      modulo: permiso.modulo,
      descripcion: permiso.descripcion,
    }));
  });

  protected readonly gruposPermisos = computed<GrupoPermisos[]>(() => {
    const grupos = new Map<string, Permiso[]>();
    for (const permiso of this.permisosDisponibles()) {
      const actuales = grupos.get(permiso.modulo) ?? [];
      actuales.push(permiso);
      grupos.set(permiso.modulo, actuales);
    }
    return [...grupos.entries()].map(([modulo, permisos]) => ({ modulo, permisos }));
  });

  protected readonly totalPermisos = computed(() => this.permisosDisponibles().length);
  protected readonly totalSeleccionados = computed(() => this.seleccionados().size);

  ngOnInit(): void {
    this.api.cargarRoles().subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
    this.api.cargarPermisos().subscribe({ error: () => undefined });
  }

  // ---------- Utilidades de la vista ----------

  protected cambiarEstado(evento: Event): void {
    const valor = (evento.target as HTMLSelectElement).value;
    if (valor === 'todos' || valor === 'activos' || valor === 'inactivos') {
      this.filtroEstado.set(valor);
    }
  }

  protected limpiarFiltros(): void {
    this.busqueda.set('');
    this.filtroEstado.set('todos');
  }

  // ---------- Alta / edición ----------

  protected abrirAlta(): void {
    this.rolEditando.set(null);
    this.nombre.set('');
    this.descripcion.set('');
    this.intentado.set(false);
    this.modalFormulario.set(true);
  }

  protected abrirEdicion(rol: Rol): void {
    this.rolEditando.set(rol);
    this.nombre.set(rol.nombre);
    this.descripcion.set(rol.descripcion ?? '');
    this.intentado.set(false);
    this.modalFormulario.set(true);
  }

  protected cerrarFormulario(): void {
    this.modalFormulario.set(false);
  }

  protected async guardar(): Promise<void> {
    this.intentado.set(true);

    if (!this.formularioValido() || this.guardando()) {
      return;
    }

    const nombre = this.nombre().trim();
    const descripcion = this.descripcion().trim() || null;
    const editando = this.rolEditando();

    this.guardando.set(true);
    try {
      if (editando) {
        const datos: RolActualizar = {
          nombre,
          descripcion,
          activo: editando.activo,
        };
        await firstValueFrom(this.api.actualizarRol(editando.id_rol, datos));
        this.toasts.exito('Rol actualizado', nombre);
      } else {
        const datos: RolCrear = { nombre, descripcion };
        await firstValueFrom(this.api.crearRol(datos));
        this.toasts.exito('Rol creado', nombre);
      }

      this.modalFormulario.set(false);
      this.api.cargarRoles().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardando.set(false);
    }
  }

  // ---------- Estado de roles ----------

  protected async desactivar(rol: Rol): Promise<void> {
    if (!this.puedeGestionar()) {
      return;
    }

    const aceptada = await this.confirmacion.confirmar({
      titulo: 'Desactivar rol',
      mensaje: `¿Desea desactivar el rol ${rol.nombre}?`,
      detalle: 'Los usuarios que lo tengan asignado dejarán de recibir sus permisos efectivos.',
      textoConfirmar: 'Desactivar',
      variante: 'peligro',
    });

    if (!aceptada) {
      return;
    }

    try {
      await firstValueFrom(this.api.desactivarRol(rol.id_rol));
      this.toasts.exito('Rol desactivado', rol.nombre);
      this.api.cargarRoles().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    }
  }

  protected async reactivar(rol: Rol): Promise<void> {
    if (!this.puedeGestionar()) {
      return;
    }

    try {
      await firstValueFrom(
        this.api.actualizarRol(rol.id_rol, {
          nombre: rol.nombre,
          descripcion: rol.descripcion,
          activo: true,
        }),
      );
      this.toasts.exito('Rol reactivado', rol.nombre);
      this.api.cargarRoles().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    }
  }

  // ---------- Permisos ----------

  protected abrirPermisos(rol: Rol): void {
    this.rolPermisos.set(rol);
    this.seleccionados.set(new Set());
    this.modalPermisos.set(true);
    void this.cargarPermisosDelRol(rol.id_rol);
  }

  protected cerrarPermisos(): void {
    this.modalPermisos.set(false);
  }

  protected estaSeleccionado(codigo: string): boolean {
    return this.seleccionados().has(codigo);
  }

  protected alternarPermiso(codigo: string): void {
    this.seleccionados.update((actuales) => {
      const copia = new Set(actuales);
      if (copia.has(codigo)) {
        copia.delete(codigo);
      } else {
        copia.add(codigo);
      }
      return copia;
    });
  }

  protected marcarTodos(): void {
    this.seleccionados.set(new Set(this.permisosDisponibles().map((permiso) => permiso.codigo)));
  }

  protected limpiarSeleccion(): void {
    this.seleccionados.set(new Set());
  }

  protected async guardarPermisos(): Promise<void> {
    const rol = this.rolPermisos();

    if (!rol || this.guardandoPermisos()) {
      return;
    }

    const permisos = [...this.seleccionados()];
    this.guardandoPermisos.set(true);
    try {
      await firstValueFrom(this.api.sincronizarPermisosRol(rol.id_rol, permisos));
      this.toasts.exito(
        'Permisos actualizados',
        `${permisos.length} permisos asignados al rol ${rol.nombre}.`,
      );
      this.modalPermisos.set(false);
      this.api.cargarRoles().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardandoPermisos.set(false);
    }
  }

  private async cargarPermisosDelRol(idRol: number): Promise<void> {
    this.cargandoPermisos.set(true);
    try {
      const permisos = await firstValueFrom(this.api.listarPermisosRol(idRol));
      this.seleccionados.set(new Set(permisos.map((permiso) => permiso.codigo)));
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.cargandoPermisos.set(false);
    }
  }

  private notificarError(error: unknown): void {
    const { mensaje, detalle } = describirError(error);
    this.toasts.error(mensaje, detalle);
  }
}
