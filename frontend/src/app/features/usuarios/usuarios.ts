import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import { firstValueFrom } from 'rxjs';
import type {
  PermisoAsignado,
  Rol,
  Usuario,
  UsuarioActualizar,
  UsuarioCrear,
  UsuarioPassword,
} from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ConfirmacionService } from '../../core/services/confirmacion.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { formatearFechaHora } from '../../core/utils/formato';
import { Modal } from '../../shared/components/modal/modal';

const PATRON_EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

type FiltroEstado = 'todos' | 'activos' | 'inactivos';

/**
 * Gestión de usuarios del sistema.
 *
 * Lista, filtra, crea y edita cuentas, cambia contraseñas y administra los
 * roles asignados. Todo el estado de la vista vive en signals; las acciones
 * de escritura se ocultan si el usuario no tiene ``usuarios:gestionar``.
 */
@Component({
  selector: 'app-usuarios',
  imports: [Modal],
  templateUrl: './usuarios.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './usuarios.scss',
})
export class Usuarios implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly toasts = inject(ToastService);
  private readonly confirmacion = inject(ConfirmacionService);

  protected readonly usuarios = this.api.usuarios;
  protected readonly rolesCatalogo = this.api.rolesCatalogo;
  protected readonly formatearFechaHora = formatearFechaHora;

  protected readonly puedeGestionar = computed(() => this.auth.tienePermiso('usuarios:gestionar'));

  // ---------- Filtros ----------

  protected readonly busqueda = signal('');
  protected readonly filtroEstado = signal<FiltroEstado>('todos');
  protected readonly filtroRol = signal('');

  protected readonly usuariosFiltrados = computed(() => {
    const termino = this.busqueda().trim().toLowerCase();
    const estado = this.filtroEstado();
    const rol = this.filtroRol();

    return this.usuarios.datos().filter((usuario) => {
      if (termino && !`${usuario.nombre} ${usuario.email}`.toLowerCase().includes(termino)) {
        return false;
      }
      if (estado === 'activos' && !usuario.activo) {
        return false;
      }
      if (estado === 'inactivos' && usuario.activo) {
        return false;
      }
      if (rol && !this.rolesDe(usuario).includes(rol)) {
        return false;
      }
      return true;
    });
  });

  protected readonly rolesFiltro = computed<string[]>(() => {
    const nombres = new Set<string>();
    for (const usuario of this.usuarios.datos()) {
      for (const rol of this.rolesDe(usuario)) {
        nombres.add(rol);
      }
    }
    return [...nombres].sort((a, b) => a.localeCompare(b, 'es'));
  });

  // ---------- Modal de alta ----------

  protected readonly modalAlta = signal(false);
  protected readonly nombre = signal('');
  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly idRol = signal<number | null>(null);
  protected readonly intentadoAlta = signal(false);
  protected readonly guardandoAlta = signal(false);

  protected readonly errorNombre = computed(() => {
    const valor = this.nombre().trim();
    if (!valor) {
      return 'El nombre es obligatorio.';
    }
    if (valor.length > 100) {
      return 'El nombre no debe superar los 100 caracteres.';
    }
    return '';
  });

  protected readonly errorEmail = computed(() => {
    const valor = this.email().trim();
    if (!valor) {
      return 'El correo es obligatorio.';
    }
    if (valor.length > 150) {
      return 'El correo no debe superar los 150 caracteres.';
    }
    if (!PATRON_EMAIL.test(valor)) {
      return 'Ingrese un correo válido.';
    }
    return '';
  });

  protected readonly errorPassword = computed(() => {
    const valor = this.password();
    if (!valor) {
      return 'La contraseña es obligatoria.';
    }
    if (valor.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (valor.length > 128) {
      return 'La contraseña no debe superar los 128 caracteres.';
    }
    return '';
  });

  protected readonly formularioValido = computed(
    () => !this.errorNombre() && !this.errorEmail() && !this.errorPassword(),
  );

  // ---------- Modal de edición ----------

  protected readonly modalEdicion = signal(false);
  protected readonly usuarioEditando = signal<Usuario | null>(null);
  protected readonly nombreEdicion = signal('');
  protected readonly emailEdicion = signal('');
  protected readonly activoEdicion = signal(true);
  protected readonly intentadoEdicion = signal(false);
  protected readonly guardandoEdicion = signal(false);

  protected readonly errorNombreEdicion = computed(() => {
    const valor = this.nombreEdicion().trim();
    if (!valor) {
      return 'El nombre es obligatorio.';
    }
    if (valor.length > 100) {
      return 'El nombre no debe superar los 100 caracteres.';
    }
    return '';
  });

  protected readonly errorEmailEdicion = computed(() => {
    const valor = this.emailEdicion().trim();
    if (!valor) {
      return 'El correo es obligatorio.';
    }
    if (valor.length > 150) {
      return 'El correo no debe superar los 150 caracteres.';
    }
    if (!PATRON_EMAIL.test(valor)) {
      return 'Ingrese un correo válido.';
    }
    return '';
  });

  protected readonly formularioEdicionValido = computed(
    () => !this.errorNombreEdicion() && !this.errorEmailEdicion(),
  );

  // ---------- Modal de roles ----------

  protected readonly modalRoles = signal(false);
  protected readonly usuarioRoles = signal<Usuario | null>(null);
  protected readonly rolesAsignados = signal<Rol[]>([]);
  protected readonly permisosEfectivos = signal<PermisoAsignado[]>([]);
  protected readonly idRolSeleccionado = signal<number | null>(null);
  protected readonly cargandoRoles = signal(false);
  protected readonly guardandoRol = signal(false);

  protected readonly rolesParaAsignar = computed(() => {
    const asignados = new Set(this.rolesAsignados().map((rol) => rol.id_rol));
    return this.rolesCatalogo.datos().filter((rol) => rol.activo && !asignados.has(rol.id_rol));
  });

  // ---------- Modal de contraseña ----------

  protected readonly modalPassword = signal(false);
  protected readonly usuarioPassword = signal<Usuario | null>(null);
  protected readonly passwordNueva = signal('');
  protected readonly confirmacionPassword = signal('');
  protected readonly intentadoPassword = signal(false);
  protected readonly guardandoPassword = signal(false);

  protected readonly errorPasswordNueva = computed(() => {
    const valor = this.passwordNueva();
    if (!valor) {
      return 'La contraseña es obligatoria.';
    }
    if (valor.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return '';
  });

  protected readonly errorConfirmacionPassword = computed(() => {
    if (!this.confirmacionPassword()) {
      return 'Confirme la contraseña.';
    }
    if (this.confirmacionPassword() !== this.passwordNueva()) {
      return 'Las contraseñas no coinciden.';
    }
    return '';
  });

  protected readonly formularioPasswordValido = computed(
    () => !this.errorPasswordNueva() && !this.errorConfirmacionPassword(),
  );

  ngOnInit(): void {
    this.api.cargarUsuarios().subscribe({
      error: (error: unknown) => this.notificarError(error),
    });
    this.api.cargarRoles(true).subscribe({ error: () => undefined });
  }

  // ---------- Utilidades de la vista ----------

  protected rolesDe(usuario: Usuario): string[] {
    return (usuario.roles ?? '')
      .split(',')
      .map((rol) => rol.trim())
      .filter((rol) => rol.length > 0);
  }

  protected esPropio(usuario: Usuario | null): boolean {
    const actual = this.auth.usuario();
    return !!usuario && actual !== null && actual.id_usuario === usuario.id_usuario;
  }

  protected cambiarEstado(evento: Event): void {
    const valor = (evento.target as HTMLSelectElement).value;
    if (valor === 'todos' || valor === 'activos' || valor === 'inactivos') {
      this.filtroEstado.set(valor);
    }
  }

  protected limpiarFiltros(): void {
    this.busqueda.set('');
    this.filtroEstado.set('todos');
    this.filtroRol.set('');
  }

  protected cambiarRolSeleccionado(evento: Event): void {
    const valor = Number((evento.target as HTMLSelectElement).value);
    this.idRolSeleccionado.set(Number.isFinite(valor) && valor > 0 ? valor : null);
  }

  // ---------- Alta ----------

  protected abrirAlta(): void {
    this.nombre.set('');
    this.email.set('');
    this.password.set('');
    this.idRol.set(null);
    this.intentadoAlta.set(false);
    this.modalAlta.set(true);
  }

  protected cerrarAlta(): void {
    this.modalAlta.set(false);
  }

  protected async crearUsuario(): Promise<void> {
    this.intentadoAlta.set(true);

    if (!this.formularioValido() || this.guardandoAlta()) {
      return;
    }

    const datos: UsuarioCrear = {
      nombre: this.nombre().trim(),
      email: this.email().trim(),
      password: this.password(),
      id_rol: this.idRol(),
    };

    this.guardandoAlta.set(true);
    try {
      await firstValueFrom(this.api.crearUsuario(datos));
      this.toasts.exito('Usuario creado', `${datos.nombre} ya puede iniciar sesión.`);
      this.modalAlta.set(false);
      this.api.cargarUsuarios().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardandoAlta.set(false);
    }
  }

  // ---------- Edición ----------

  protected abrirEdicion(usuario: Usuario): void {
    this.usuarioEditando.set(usuario);
    this.nombreEdicion.set(usuario.nombre);
    this.emailEdicion.set(usuario.email);
    this.activoEdicion.set(usuario.activo);
    this.intentadoEdicion.set(false);
    this.modalEdicion.set(true);
  }

  protected cerrarEdicion(): void {
    this.modalEdicion.set(false);
  }

  protected async guardarEdicion(): Promise<void> {
    this.intentadoEdicion.set(true);
    const usuario = this.usuarioEditando();

    if (!usuario || !this.formularioEdicionValido() || this.guardandoEdicion()) {
      return;
    }

    const datos: UsuarioActualizar = {
      nombre: this.nombreEdicion().trim(),
      email: this.emailEdicion().trim(),
      activo: this.activoEdicion(),
    };

    this.guardandoEdicion.set(true);
    try {
      await firstValueFrom(this.api.actualizarUsuario(usuario.id_usuario, datos));
      this.toasts.exito('Usuario actualizado', datos.nombre);
      this.modalEdicion.set(false);
      this.api.cargarUsuarios().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardandoEdicion.set(false);
    }
  }

  // ---------- Roles ----------

  protected abrirRoles(usuario: Usuario): void {
    this.usuarioRoles.set(usuario);
    this.rolesAsignados.set([]);
    this.permisosEfectivos.set([]);
    this.idRolSeleccionado.set(null);
    this.modalRoles.set(true);
    void this.cargarRolesDelUsuario(usuario.id_usuario);
  }

  protected cerrarRoles(): void {
    this.modalRoles.set(false);
  }

  protected async agregarRol(): Promise<void> {
    const usuario = this.usuarioRoles();
    const idRol = this.idRolSeleccionado();

    if (!usuario || idRol === null || this.guardandoRol()) {
      return;
    }

    this.guardandoRol.set(true);
    try {
      await firstValueFrom(this.api.asignarRolUsuario(usuario.id_usuario, { id_rol: idRol }));
      const rol = this.rolesCatalogo.datos().find((item) => item.id_rol === idRol);
      this.toasts.exito('Rol asignado', rol?.nombre ?? 'El rol se asignó correctamente.');
      this.idRolSeleccionado.set(null);
      await this.cargarRolesDelUsuario(usuario.id_usuario);
      this.api.cargarUsuarios().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardandoRol.set(false);
    }
  }

  protected async quitarRol(rol: Rol): Promise<void> {
    const usuario = this.usuarioRoles();

    if (!usuario || this.guardandoRol()) {
      return;
    }

    this.guardandoRol.set(true);
    try {
      await firstValueFrom(this.api.quitarRolUsuario(usuario.id_usuario, rol.id_rol));
      this.toasts.exito('Rol retirado', rol.nombre);
      await this.cargarRolesDelUsuario(usuario.id_usuario);
      this.api.cargarUsuarios().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardandoRol.set(false);
    }
  }

  private async cargarRolesDelUsuario(idUsuario: number): Promise<void> {
    this.cargandoRoles.set(true);
    try {
      const [roles, permisos] = await Promise.all([
        firstValueFrom(this.api.listarRolesUsuario(idUsuario)),
        firstValueFrom(this.api.listarPermisosUsuario(idUsuario)),
      ]);
      this.rolesAsignados.set(roles);
      this.permisosEfectivos.set(permisos);
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.cargandoRoles.set(false);
    }
  }

  // ---------- Contraseña ----------

  protected abrirPassword(usuario: Usuario): void {
    this.usuarioPassword.set(usuario);
    this.passwordNueva.set('');
    this.confirmacionPassword.set('');
    this.intentadoPassword.set(false);
    this.modalPassword.set(true);
  }

  protected cerrarPassword(): void {
    this.modalPassword.set(false);
  }

  protected async cambiarPassword(): Promise<void> {
    this.intentadoPassword.set(true);
    const usuario = this.usuarioPassword();

    if (!usuario || !this.formularioPasswordValido() || this.guardandoPassword()) {
      return;
    }

    const datos: UsuarioPassword = { password: this.passwordNueva() };

    this.guardandoPassword.set(true);
    try {
      await firstValueFrom(this.api.cambiarPasswordUsuario(usuario.id_usuario, datos));
      this.toasts.exito(
        'Contraseña actualizada',
        `La contraseña de ${usuario.nombre} se cambió correctamente.`,
      );
      this.modalPassword.set(false);
    } catch (error: unknown) {
      this.notificarError(error);
    } finally {
      this.guardandoPassword.set(false);
    }
  }

  // ---------- Desactivación ----------

  protected async desactivar(usuario: Usuario): Promise<void> {
    if (!this.puedeGestionar() || this.esPropio(usuario)) {
      return;
    }

    const aceptada = await this.confirmacion.confirmar({
      titulo: 'Desactivar usuario',
      mensaje: `¿Desea desactivar la cuenta de ${usuario.nombre}?`,
      detalle: 'El usuario no podrá iniciar sesión hasta que vuelva a activarse.',
      textoConfirmar: 'Desactivar',
      variante: 'peligro',
    });

    if (!aceptada) {
      return;
    }

    try {
      await firstValueFrom(this.api.desactivarUsuario(usuario.id_usuario));
      this.toasts.exito('Usuario desactivado', usuario.nombre);
      this.api.cargarUsuarios().subscribe({ error: () => undefined });
    } catch (error: unknown) {
      this.notificarError(error);
    }
  }

  private notificarError(error: unknown): void {
    const { mensaje, detalle } = describirError(error);
    this.toasts.error(mensaje, detalle);
  }
}
