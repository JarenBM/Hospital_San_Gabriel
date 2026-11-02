import { Component, computed, inject, signal } from '@angular/core';
import {
  email as validarEmail,
  form,
  FormField,
  minLength,
  required,
  submit,
} from '@angular/forms/signals';
import { ActivatedRoute, Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import type { ApiError } from '../../../models';
import { AuthService } from '../../../core/services/auth.service';
import { normalizarErrorHttp } from '../../../core/utils/api-error';

interface DatosLogin {
  email: string;
  password: string;
}

/**
 * Inicio de sesión con Signal Forms (Angular 21).
 *
 * El modelo del formulario, el estado de carga y el error son signals. Tras
 * autenticar, redirige al ``returnUrl`` solicitado o a la ruta de inicio del
 * rol (dashboard, movimientos o productos).
 */
@Component({
  selector: 'app-login',
  imports: [FormField],
  templateUrl: './login.html',
  styleUrl: './login.scss',
})
export class Login {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly ruta = inject(ActivatedRoute);

  protected readonly loginModel = signal<DatosLogin>({
    email: '',
    password: '',
  });

  protected readonly loginForm = form(this.loginModel, (campo) => {
    required(campo.email, { message: 'El correo es obligatorio' });
    validarEmail(campo.email, { message: 'Ingrese un correo válido' });
    required(campo.password, { message: 'La contraseña es obligatoria' });
    minLength(campo.password, 8, {
      message: 'La contraseña debe tener al menos 8 caracteres',
    });
  });

  protected readonly email = computed(() => this.loginModel().email);
  protected readonly password = computed(() => this.loginModel().password);

  protected readonly cargando = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly mostrarPassword = signal(false);
  protected readonly anio = new Date().getFullYear();

  private readonly returnUrl = this.obtenerReturnUrl();

  protected async enviar(evento: Event): Promise<void> {
    evento.preventDefault();

    if (this.cargando()) {
      return;
    }

    this.error.set(null);

    await submit(this.loginForm, {
      action: async () => {
        this.cargando.set(true);
        try {
          const usuario = await firstValueFrom(
            this.auth.login(this.email(), this.password()),
          );

          const destino =
            this.returnUrl ?? this.auth.rutaInicioPara(usuario);

          await this.router.navigateByUrl(destino, { replaceUrl: true });
        } catch (error: unknown) {
          const apiError = normalizarErrorHttp(error);
          this.error.set(this.mensajeError(apiError));
        } finally {
          this.cargando.set(false);
        }
      },
    });
  }

  protected alternarPassword(): void {
    this.mostrarPassword.update((visible) => !visible);
  }

  private obtenerReturnUrl(): string | null {
    const url = this.ruta.snapshot.queryParamMap.get('returnUrl');
    if (!url || !url.startsWith('/') || url.startsWith('//')) {
      return null;
    }
    if (url.startsWith('/login')) {
      return null;
    }
    return url;
  }

  private mensajeError(error: ApiError): string {
    const detalle = error.detalle?.trim();
    if (!detalle || detalle === error.mensaje) {
      return error.mensaje;
    }
    return `${error.mensaje}: ${detalle}`;
  }
}
