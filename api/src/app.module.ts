import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AllExceptionsFilter, ResponseInterceptor } from './common/api-response';
import { AuthGuard } from './common/auth';
import { PrismaModule } from './common/prisma.service';
import { AuthModule } from './modules/auth/auth.module';
import { ChatModule } from './modules/chat/chat.module';
import { CheckInsModule } from './modules/checkins/checkins.module';
import { ClassesModule } from './modules/classes/classes.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';
import { GraduationsModule } from './modules/graduations/graduations.module';
import { InvoicesModule } from './modules/invoices/invoices.module';
import { LeadsModule } from './modules/leads/leads.module';
import { MembershipsModule } from './modules/memberships/memberships.module';
import { ModalitiesModule } from './modules/modalities/modalities.module';
import { PlansModule } from './modules/plans/plans.module';
import { StudentAppModule } from './modules/student-app/student-app.module';
import { StudentsModule } from './modules/students/students.module';
import { TracksModule } from './modules/tracks/tracks.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: { expiresIn: '12h' },
      }),
    }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 300 }]),
    PrismaModule,
    AuthModule,
    ChatModule,
    StudentsModule,
    ModalitiesModule,
    PlansModule,
    MembershipsModule,
    InvoicesModule,
    ClassesModule,
    CheckInsModule,
    GraduationsModule,
    LeadsModule,
    DashboardModule,
    StudentAppModule,
    TracksModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_INTERCEPTOR, useClass: ResponseInterceptor },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule {}
