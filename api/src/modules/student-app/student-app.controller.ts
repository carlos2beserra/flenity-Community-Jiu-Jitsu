import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, StudentOnly } from '../../common/auth';
import { ChangePasswordDto, SelfCheckInDto, StudentHistoryQuery } from './student-app.dto';
import { StudentAppService } from './student-app.service';

@StudentOnly()
@Controller('student')
export class StudentAppController {
  constructor(private readonly app: StudentAppService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.app.me(user.academyId, user.userId);
  }

  @Get('classes')
  classes(@CurrentUser() user: AuthUser) {
    return this.app.classes(user.academyId, user.userId);
  }

  @Post('check-ins')
  checkIn(@CurrentUser() user: AuthUser, @Body() dto: SelfCheckInDto) {
    return this.app.selfCheckIn(user.academyId, user.userId, dto.classId);
  }

  @Get('check-ins')
  history(@CurrentUser() user: AuthUser, @Query() query: StudentHistoryQuery) {
    return this.app.history(user.academyId, user.userId, query);
  }

  @Get('invoices')
  invoices(@CurrentUser() user: AuthUser) {
    return this.app.invoices(user.academyId, user.userId);
  }

  @Post('password')
  changePassword(@CurrentUser() user: AuthUser, @Body() dto: ChangePasswordDto) {
    return this.app.changePassword(user.academyId, user.userId, dto);
  }
}
