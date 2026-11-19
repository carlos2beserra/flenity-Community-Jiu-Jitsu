import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { DeviceCredentialsService } from './device-credentials.service';

@Module({ controllers: [AuthController], providers: [AuthService, DeviceCredentialsService] })
export class AuthModule {}
