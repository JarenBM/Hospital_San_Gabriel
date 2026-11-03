import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { CargaGlobal } from './shared/components/feedback/carga-global';
import { ConfirmDialog } from './shared/components/feedback/confirm-dialog';
import { Toasts } from './shared/components/feedback/toasts';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, CargaGlobal, Toasts, ConfirmDialog],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {}
