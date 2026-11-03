import { Component, inject } from '@angular/core';
import { CargaGlobalService } from '../../../core/services/carga-global.service';

/** Barra superior de progreso mientras hay peticiones en curso. */
@Component({
  selector: 'app-carga-global',
  template: `
    @if (carga.isLoading()) {
      <div class="carga-global" role="progressbar" aria-label="Cargando información">
        <span class="carga-global__barra"></span>
      </div>
    }
  `,
  styles: `
    .carga-global {
      position: fixed;
      inset: 0 0 auto;
      z-index: 1090;
      height: 3px;
      overflow: hidden;
      background-color: rgb(15 110 110 / 15%);
      pointer-events: none;
    }

    .carga-global__barra {
      display: block;
      width: 40%;
      height: 100%;
      background: linear-gradient(90deg, #0f6e6e, #1d7fd4);
      animation: carga-global 1.1s ease-in-out infinite;
    }

    @keyframes carga-global {
      0% {
        transform: translateX(-110%);
      }
      100% {
        transform: translateX(280%);
      }
    }

    @media (prefers-reduced-motion: reduce) {
      .carga-global__barra {
        width: 100%;
        animation: none;
      }
    }
  `,
})
export class CargaGlobal {
  protected readonly carga = inject(CargaGlobalService);
}
