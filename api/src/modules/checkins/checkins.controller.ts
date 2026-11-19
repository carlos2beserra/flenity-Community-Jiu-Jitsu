import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreateCheckInDto, ListCheckInsQuery } from './checkins.dto';
import { CheckInsService } from './checkins.service';

@Controller('check-ins')
export class CheckInsController {
  constructor(private readonly checkIns: CheckInsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: ListCheckInsQuery) {
    return this.checkIns.list(user.academyId, query);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCheckInDto) {
    return this.checkIns.create(user.academyId, dto);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Delete(':id')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.checkIns.remove(user.academyId, id);
  }
}
