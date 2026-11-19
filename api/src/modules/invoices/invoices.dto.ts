import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { PaymentMethod } from '@prisma/client';
import { PaginationQuery } from '../../common/pagination';

export const INVOICE_FILTERS = ['PENDING', 'PAID', 'CANCELED', 'OVERDUE'] as const;

export class ListInvoicesQuery extends PaginationQuery {
  @IsOptional() @IsIn(INVOICE_FILTERS)
  status?: (typeof INVOICE_FILTERS)[number];

  @IsOptional() @IsUUID()
  studentId?: string;

  /** Formato YYYY-MM: filtra por mês de vencimento. */
  @IsOptional() @IsString() @MinLength(7) @MaxLength(7)
  month?: string;
}

export class CreateInvoiceDto {
  @IsUUID()
  studentId: string;

  @IsString() @MinLength(2) @MaxLength(120)
  description: string;

  @IsInt() @Min(1)
  amountCents: number;

  @IsDateString()
  dueDate: string;
}

export class PayInvoiceDto {
  @IsIn(Object.values(PaymentMethod))
  paymentMethod: PaymentMethod;

  @IsOptional() @IsDateString()
  paidAt?: string;
}

export class GenerateInvoicesDto {
  @Type(() => Number) @IsInt() @Min(2000) @Max(2100)
  year: number;

  /** 1-12 */
  @Type(() => Number) @IsInt() @Min(1) @Max(12)
  month: number;
}
