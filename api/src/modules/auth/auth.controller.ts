import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AllAuthenticated, AuthUser, CurrentUser, Public, Roles } from '../../common/auth';
import {
  CreateUserDto,
  DeviceCredentialDto,
  DeviceLoginDto,
  LoginDto,
  RegisterAcademyDto,
  StudentLoginDto,
} from './auth.dto';
import { AuthService } from './auth.service';
import { DeviceCredentialsService } from './device-credentials.service';

@Controller()
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly devices: DeviceCredentialsService,
  ) {}

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('auth/register')
  register(@Body() dto: RegisterAcademyDto) {
    return this.auth.registerAcademy(dto);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('auth/login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('auth/student/login')
  studentLogin(@Body() dto: StudentLoginDto) {
    return this.auth.studentLogin(dto);
  }

  /** Ativa a entrada com biometria neste aparelho (aluno ou equipe já logados). */
  @AllAuthenticated()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('auth/device-credentials')
  enrollDevice(@CurrentUser() user: AuthUser, @Body() dto: DeviceCredentialDto) {
    return this.devices.enroll(user, dto);
  }

  @AllAuthenticated()
  @Delete('auth/device-credentials/:credentialId')
  revokeDevice(@CurrentUser() user: AuthUser, @Param('credentialId', ParseUUIDPipe) credentialId: string) {
    return this.devices.revoke(user, credentialId);
  }

  /** Entrada com biometria: troca o segredo do aparelho por um novo token. */
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('auth/device-login')
  deviceLogin(@Body() dto: DeviceLoginDto) {
    return this.devices.login(dto);
  }

  @Get('auth/me')
  me(@CurrentUser() user: AuthUser) {
    return this.auth.me(user.userId);
  }

  @Get('users')
  listUsers(@CurrentUser() user: AuthUser) {
    return this.auth.listUsers(user.academyId);
  }

  @Roles('ADMIN')
  @Post('users')
  createUser(@CurrentUser() user: AuthUser, @Body() dto: CreateUserDto) {
    return this.auth.createUser(user.academyId, dto);
  }
}
