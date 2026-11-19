import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreateMembershipDto, ListMembershipsQuery } from './memberships.dto';
import { MembershipsService } from './memberships.service';

@Controller('memberships')
export class MembershipsController {
  constructor(private readonly memberships: MembershipsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: ListMembershipsQuery) {
    return this.memberships.list(user.academyId, query);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateMembershipDto) {
    return this.memberships.create(user.academyId, dto);
  }

  @Roles('ADMIN', 'RECEPTION')
  @Post(':id/cancel')
  cancel(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.memberships.cancel(user.academyId, id);
  }
}
