import {
  Component,
  computed,
  inject,
  OnInit,
  signal,
  ChangeDetectionStrategy,
} from '@angular/core';
import type { Categoria } from '../../models';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ConfirmacionService } from '../../core/services/confirmacion.service';
import { ToastService } from '../../core/services/toast.service';
import { describirError } from '../../core/utils/errores';
import { Modal } from '../../shared/components/modal/modal';

/** Opciones del filtro por estado de la categoría. */
type FiltroEstado = 'todos' | 'activos' | 'inactivos';

const MAX_NOMBRE = 100;
const MAX_DESCRIPCION = 255;

/**
 * Catálogo de categorías.
 *
 * Filtra en cliente sobre la caché de ``ApiService.categorias``. Además de
 * crear, editar y desactivar, permite reactivar una categoría inactiva con
 * ``PUT`` y ``activo: true``, operación que sí admite el backend.
 */
@Component({
  selector: 'app-categorias',
  imports: [Modal],
  templateUrl: './categorias.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './categorias.scss',
})
export class Categorias implements OnInit {
  protected readonly auth = inject(AuthService);
  private readonly api = inject(ApiService);
  private readonly toasts = inject(ToastService);
  private readonly confirmacion = inject(ConfirmacionService);

  protected readonly categorias = this.api.categorias;

  protected readonly puedeEscribir = computed(() => this.auth.tienePermiso('categorias:escribir'));

  // ---------- Filtros ----------

  protected readonly filtroBusqueda = signal('');
  protected readonly filtroEstado = signal<FiltroEstado>('todos');

  protected readonly hayFiltros = computed(
    () => this.filtroBusqueda().trim() !== '' || this.filtroEstado() !== 'todos',
  );

  // ---------- Modal ----------

  protected readonly modalAbierto = signal(false);
  protected readonly categoriaEditando = signal<Categoria | null>(null);
  protected readonly guardando = signal(false);
  protected readonly reactivandoId = signal<number | null>(null);
  protected readonly errorModal = signal<string | null>(null);
  protected readonly intentado = signal(false);

  // ---------- Formulario ----------

  protected readonly nombre = signal('');
  protected readonly descripcion = signal('');

  // ---------- Derivados ----------

  protected readonly categoriasFiltradas = computed(() => {
    const busqueda = this.filtroBusqueda().trim().toLowerCase();
    const estado = this.filtroEstado();

    return this.categorias.datos().filter((categoria) => {
      if (estado === 'activos' && !categoria.activo) {
        return false;
      }
      if (estado === 'inactivos' && categoria.activo) {
        return false;
      }
      if (busqueda) {
        const texto = `${categoria.nombre} ${categoria.descripcion ?? ''}`.toLowerCase();
        if (!texto.includes(busqueda)) {
          return false;
        }
      }
      return true;
    });
  });

  protected readonly cargandoInicial = computed(
    () => this.categorias.cargando() && this.categorias.datos().length === 0,
  );

  protected readonly esEdicion = computed(() => this.categoriaEditando() !== null);

  protected readonly tituloModal = computed(() =>
    this.esEdicion() ? 'Editar categoría' : 'Nueva categoría',
  );

  // ---------- Validaciones ----------

  protected readonly errorNombre = computed<string | null>(() => {
    const valor = this.nombre().trim();
    if (!valor) {
      return 'El nombre es obligatorio.';
    }
    if (valor.length > MAX_NOMBRE) {
      return `El nombre no puede superar los ${MAX_NOMBRE} caracteres.`;
    }
    return null;
  });

  protected readonly errorDescripcion = computed<string | null>(() => {
    if (this.descripcion().trim().length > MAX_DESCRIPCION) {
      return `La descripción no puede superar los ${MAX_DESCRIPCION} caracteres.`;
    }
    return null;
  });

  protected readonly formularioValido = computed(
    () => this.errorNombre() === null && this.errorDescripcion() === null,
  );

  ngOnInit(): void {
    this.recargarCategorias();
  }

  // ---------- Carga ----------

  protected recargarCategorias(): void {
    this.api.cargarCategorias().subscribe({ error: () => undefined });
  }

  // ---------- Filtros ----------

  protected cambiarFiltroBusqueda(evento: Event): void {
    this.filtroBusqueda.set(this.valorDe(evento));
  }

  protected cambiarFiltroEstado(evento: Event): void {
    const valor = this.valorDe(evento);
    this.filtroEstado.set(valor === 'activos' || valor === 'inactivos' ? valor : 'todos');
  }

  protected limpiarFiltros(): void {
    this.filtroBusqueda.set('');
    this.filtroEstado.set('todos');
  }

  // ---------- Modal ----------

  protected abrirCrear(): void {
    if (!this.puedeEscribir()) {
      return;
    }
    this.prepararFormulario(null);
  }

  protected abrirEditar(categoria: Categoria): void {
    if (!this.puedeEscribir()) {
      return;
    }
    this.prepararFormulario(categoria);
  }

  protected cerrarModal(): void {
    if (this.guardando()) {
      return;
    }
    this.modalAbierto.set(false);
    this.errorModal.set(null);
    this.intentado.set(false);
  }

  protected cambiarNombre(evento: Event): void {
    this.nombre.set(this.valorDe(evento));
  }

  protected cambiarDescripcion(evento: Event): void {
    this.descripcion.set(this.valorDe(evento));
  }

  protected guardar(evento: Event): void {
    evento.preventDefault();
    this.intentado.set(true);

    if (this.guardando() || !this.formularioValido()) {
      return;
    }

    const editando = this.categoriaEditando();
    const datos = {
      nombre: this.nombre().trim(),
      descripcion: this.descripcion().trim() || null,
    };

    this.guardando.set(true);
    this.errorModal.set(null);

    const peticion = editando
      ? this.api.actualizarCategoria(editando.id_categoria, datos)
      : this.api.crearCategoria(datos);

    peticion.subscribe({
      next: (categoria) => {
        this.guardando.set(false);
        this.modalAbierto.set(false);
        this.errorModal.set(null);
        this.intentado.set(false);
        this.toasts.exito(
          editando ? 'Categoría actualizada' : 'Categoría creada',
          categoria.nombre,
        );
        this.recargarCategorias();
      },
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        const texto = detalle ? `${mensaje}: ${detalle}` : mensaje;
        this.guardando.set(false);
        this.errorModal.set(texto);
        this.toasts.error(
          editando ? 'No se pudo actualizar la categoría' : 'No se pudo crear la categoría',
          texto,
        );
      },
    });
  }

  protected async desactivar(categoria: Categoria): Promise<void> {
    if (!this.puedeEscribir()) {
      return;
    }

    const confirmado = await this.confirmacion.confirmar({
      titulo: 'Desactivar categoría',
      mensaje: `¿Desea desactivar "${categoria.nombre}"?`,
      detalle:
        'La categoría dejará de estar disponible para nuevos productos. Podrá reactivarla más adelante.',
      textoConfirmar: 'Desactivar',
      variante: 'peligro',
      icono: 'bi-tags',
    });

    if (!confirmado) {
      return;
    }

    this.api.desactivarCategoria(categoria.id_categoria).subscribe({
      next: () => {
        this.toasts.exito('Categoría desactivada', categoria.nombre);
        this.recargarCategorias();
      },
      error: (error: unknown) => {
        const { mensaje, detalle } = describirError(error);
        this.toasts.error('No se pudo desactivar la categoría', detalle ?? mensaje);
      },
    });
  }

  protected reactivar(categoria: Categoria): void {
    if (!this.puedeEscribir() || this.reactivandoId() !== null) {
      return;
    }

    this.reactivandoId.set(categoria.id_categoria);

    this.api
      .actualizarCategoria(categoria.id_categoria, {
        nombre: categoria.nombre,
        descripcion: categoria.descripcion,
        activo: true,
      })
      .subscribe({
        next: (actualizada) => {
          this.reactivandoId.set(null);
          this.toasts.exito('Categoría reactivada', actualizada.nombre);
          this.recargarCategorias();
        },
        error: (error: unknown) => {
          const { mensaje, detalle } = describirError(error);
          this.reactivandoId.set(null);
          this.toasts.error('No se pudo reactivar la categoría', detalle ?? mensaje);
        },
      });
  }

  // ---------- Presentación ----------

  protected claseEstado(activo: boolean): string {
    return activo ? 'badge text-bg-success' : 'badge text-bg-secondary';
  }

  // ---------- Internos ----------

  private prepararFormulario(categoria: Categoria | null): void {
    this.categoriaEditando.set(categoria);
    this.nombre.set(categoria?.nombre ?? '');
    this.descripcion.set(categoria?.descripcion ?? '');
    this.errorModal.set(null);
    this.intentado.set(false);
    this.modalAbierto.set(true);
  }

  private valorDe(evento: Event): string {
    const objetivo = evento.target;
    if (
      objetivo instanceof HTMLInputElement ||
      objetivo instanceof HTMLTextAreaElement ||
      objetivo instanceof HTMLSelectElement
    ) {
      return objetivo.value;
    }
    return '';
  }
}
