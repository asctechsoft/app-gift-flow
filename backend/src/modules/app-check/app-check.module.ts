import { Global, Module } from '@nestjs/common';
import { AppCheckGuard } from './app-check.guard';
import { AppCheckVerifier } from './app-check.verifier';

@Global()
@Module({
  providers: [AppCheckVerifier, AppCheckGuard],
  exports: [AppCheckVerifier, AppCheckGuard],
})
export class AppCheckModule {}
