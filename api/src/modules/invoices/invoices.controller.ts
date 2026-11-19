import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles } from '../../common/auth';
import { CreateInvoiceDto, GenerateInvoicesDto, ListInvoicesQuery, PayInvoiceDto } from './invoices.dto';
import { InvoicesService } from './invoices.service';

@Roles('ADMIN', 'RECEPTION')
@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: ListInvoicesQuery) {
    return this.invoices.list(user.academyId, query);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateInvoiceDto) {
    return this.invoices.create(user.academyId, dto);
  }

  @Post('generate')
  generate(@CurrentUser() user: AuthUser, @Body() dto: GenerateInvoicesDto) {
    return this.invoices.generateForMonth(user.academyId, dto);
  }

  @Post(':id/pay')
  pay(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PayInvoiceDto) {
    return this.invoices.pay(user.academyId, id, dto);
  }

  @Post(':id/cancel')
  cancel(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.invoices.cancel(user.academyId, id);
  }
}
