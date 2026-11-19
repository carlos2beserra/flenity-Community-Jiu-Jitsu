import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreateLeadDto, UpdateLeadDto } from './leads.dto';
import { LeadsService } from './leads.service';

@Roles('ADMIN', 'RECEPTION')
@Controller('leads')
export class LeadsController {
  constructor(private readonly leads: LeadsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.leads.list(user.academyId);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateLeadDto) {
    return this.leads.create(user.academyId, dto);
  }

  @Patch(':id')
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateLeadDto) {
    return this.leads.update(user.academyId, id, dto);
  }

  @Post(':id/convert')
  convert(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.leads.convert(user.academyId, id);
  }
}
