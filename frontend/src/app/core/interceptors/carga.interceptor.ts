import type { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { finalize } from 'rxjs';
import { CargaGlobalService } from '../services/carga-global.service';

/** Activa la barra global de carga durante cada petición a la API. */
export const cargaInterceptor: HttpInterceptorFn = (peticion, siguiente) => {
  const carga = inject(CargaGlobalService);
  carga.iniciar();

  return siguiente(peticion).pipe(finalize(() => carga.detener()));
};
