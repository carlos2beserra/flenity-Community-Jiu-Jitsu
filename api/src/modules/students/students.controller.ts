import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { AppAccessDto, CreateStudentDto, ListStudentsQuery, RegisterStudentDto, UpdateStudentDto } from './students.dto';
import { StudentsService } from './students.service';
import { CommunityService } from '../student-app/community.service';

@Controller('students')
export class StudentsController {
  constructor(
    private readonly students: StudentsService,
    private readonly community: CommunityService,
  ) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: ListStudentsQuery) {
    return this.students.list(user.academyId, query);
  }

  @Get(':id')
  get(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.students.get(user.academyId, id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateStudentDto) {
    return this.students.create(user.academyId, dto);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Post('registration')
  register(@CurrentUser() user: AuthUser, @Body() dto: RegisterStudentDto) {
    return this.students.create(user.academyId, dto);
  }

  @Patch(':id')
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateStudentDto) {
    return this.students.update(user.academyId, id, dto);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Post(':id/app-access')
  grantAppAccess(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: AppAccessDto) {
    return this.students.grantAppAccess(user.academyId, id, dto);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Delete(':id/app-access')
  @HttpCode(200)
  revokeAppAccess(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.students.revokeAppAccess(user.academyId, id);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Post(':id/community-invite')
  createCommunityInvite(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.community.createInvite(user.academyId, id);
  }

  @Roles('ADMIN')
  @Delete(':id')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.students.remove(user.academyId, id);
  }
}
