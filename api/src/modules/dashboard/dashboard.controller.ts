import { Controller, Get } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../../common/auth';
import { DashboardService } from './dashboard.service';

@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Get()
  summary(@CurrentUser() user: AuthUser) {
    return this.dashboard.summary(user.academyId);
  }

  @Get('birthdays')
  birthdays(@CurrentUser() user: AuthUser) {
    return this.dashboard.birthdays(user.academyId);
  }
}
