import { TestBed } from '@angular/core/testing';
import { ToastService } from './toast.service';

describe('ToastService', () => {
  let servicio: ToastService;

  beforeEach(() => {
    vi.useFakeTimers();
    TestBed.configureTestingModule({});
    servicio = TestBed.inject(ToastService);
  });

  afterEach(() => {
    servicio.limpiar();
    vi.useRealTimers();
  });

  it('encola toasts y los descarta automáticamente', () => {
    servicio.exito('Guardado');
    servicio.error('Falló', 'Detalle');

    expect(servicio.total()).toBe(2);
    expect(servicio.toasts()[0].tipo).toBe('exito');
    expect(servicio.toasts()[1].detalle).toBe('Detalle');

    vi.advanceTimersByTime(9_000);

    expect(servicio.total()).toBe(0);
  });

  it('permite descartar un toast por id', () => {
    const primero = servicio.info('Uno');
    servicio.info('Dos');

    servicio.descartar(primero);

    expect(servicio.total()).toBe(1);
    expect(servicio.toasts()[0].mensaje).toBe('Dos');
  });
});
