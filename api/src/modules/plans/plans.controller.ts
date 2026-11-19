import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreatePlanDto, UpdatePlanDto } from './plans.dto';
import { PlansService } from './plans.service';

@Controller('plans')
export class PlansController {
  constructor(private readonly plans: PlansService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.plans.list(user.academyId);
  }

  @Roles('ADMIN')
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePlanDto) {
    return this.plans.create(user.academyId, dto);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdatePlanDto) {
    return this.plans.update(user.academyId, id, dto);
  }
}
