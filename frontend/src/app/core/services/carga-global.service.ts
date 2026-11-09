import { Injectable, signal } from '@angular/core';
import type { Observable } from 'rxjs';
import { finalize } from 'rxjs';

/**
 * Estado global de carga.
 *
 * Varias peticiones pueden solaparse, por eso se usa un contador: la barra
 * desaparece solo cuando la última petición termina.
 */
@Injectable({ providedIn: 'root' })
export class CargaGlobalService {
  private readonly _isLoading = signal(false);
  private pendientes = 0;

  readonly isLoading = this._isLoading.asReadonly();

  iniciar(): void {
    this.pendientes += 1;
    this._isLoading.set(true);
  }

  detener(): void {
    this.pendientes = Math.max(0, this.pendientes - 1);
    this._isLoading.set(this.pendientes > 0);
  }

  /** Ejecuta un observable mostrando la barra global mientras esté activo. */
  ejecutar<T>(fuente: Observable<T>): Observable<T> {
    this.iniciar();
    return fuente.pipe(finalize(() => this.detener()));
  }
}
