import { TestBed } from '@angular/core/testing';
import { of } from 'rxjs';
import { CargaGlobalService } from './carga-global.service';

describe('CargaGlobalService', () => {
  let servicio: CargaGlobalService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    servicio = TestBed.inject(CargaGlobalService);
  });

  it('mantiene isLoading mientras hay peticiones solapadas', () => {
    servicio.iniciar();
    servicio.iniciar();
    expect(servicio.isLoading()).toBe(true);

    servicio.detener();
    expect(servicio.isLoading()).toBe(true);

    servicio.detener();
    expect(servicio.isLoading()).toBe(false);
  });

  it('finaliza la carga al completar el observable', () => {
    servicio.ejecutar(of('ok')).subscribe();

    expect(servicio.isLoading()).toBe(false);
  });
});
