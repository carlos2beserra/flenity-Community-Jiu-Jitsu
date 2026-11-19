import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreateClassDto, UpdateClassDto } from './classes.dto';
import { ClassesService } from './classes.service';

@Controller('classes')
export class ClassesController {
  constructor(private readonly classes: ClassesService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.classes.list(user.academyId);
  }

  @Get('today')
  today(@CurrentUser() user: AuthUser) {
    return this.classes.today(user.academyId);
  }

  @Get(':id/attendance')
  attendance(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.classes.attendance(user.academyId, id);
  }

  @Roles('ADMIN')
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateClassDto) {
    return this.classes.create(user.academyId, dto);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateClassDto) {
    return this.classes.update(user.academyId, id, dto);
  }

  @Roles('ADMIN')
  @Delete(':id')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.classes.remove(user.academyId, id);
  }
}
