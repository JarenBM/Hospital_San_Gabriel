import { TestBed } from '@angular/core/testing';
import { ConfirmacionService } from './confirmacion.service';

describe('ConfirmacionService', () => {
  let servicio: ConfirmacionService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    servicio = TestBed.inject(ConfirmacionService);
  });

  it('resuelve true al aceptar y limpia la solicitud', async () => {
    const respuesta = servicio.confirmar({
      titulo: 'Desactivar',
      mensaje: '¿Confirma la acción?',
    });

    expect(servicio.solicitud()?.titulo).toBe('Desactivar');
    servicio.aceptar();

    await expect(respuesta).resolves.toBe(true);
    expect(servicio.solicitud()).toBeNull();
  });

  it('resuelve false al cancelar', async () => {
    const respuesta = servicio.confirmar({
      titulo: 'Desactivar',
      mensaje: '¿Confirma la acción?',
    });

    servicio.cancelar();

    await expect(respuesta).resolves.toBe(false);
  });

  it('cancela la confirmación anterior cuando llega otra', async () => {
    const primera = servicio.confirmar({ titulo: 'A', mensaje: 'Primera' });
    const segunda = servicio.confirmar({ titulo: 'B', mensaje: 'Segunda' });

    await expect(primera).resolves.toBe(false);
    servicio.aceptar();
    await expect(segunda).resolves.toBe(true);
  });
});
