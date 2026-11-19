import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { GraduationBoardQuery, PromoteDto } from './graduations.dto';
import { GraduationsService } from './graduations.service';

@Controller('graduations')
export class GraduationsController {
  constructor(private readonly graduations: GraduationsService) {}

  @Get()
  board(@CurrentUser() user: AuthUser, @Query() query: GraduationBoardQuery) {
    return this.graduations.board(user.academyId, query);
  }

  @Roles('ADMIN', 'INSTRUCTOR')
  @Post('promote')
  promote(@CurrentUser() user: AuthUser, @Body() dto: PromoteDto) {
    return this.graduations.promote(user.academyId, dto);
  }
}
