import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Put } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreateModalityDto, ReplaceBeltsDto } from './modalities.dto';
import { ModalitiesService } from './modalities.service';

@Controller('modalities')
export class ModalitiesController {
  constructor(private readonly modalities: ModalitiesService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.modalities.list(user.academyId);
  }

  @Roles('ADMIN')
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateModalityDto) {
    return this.modalities.create(user.academyId, dto);
  }

  @Roles('ADMIN', 'INSTRUCTOR')
  @Put(':id/belts')
  replaceBelts(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReplaceBeltsDto) {
    return this.modalities.replaceBelts(user.academyId, id, dto.belts);
  }

  @Roles('ADMIN')
  @Delete(':id')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.modalities.remove(user.academyId, id);
  }
}
