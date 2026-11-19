import { IsDateString, IsEnum, IsInt, IsOptional, IsUUID, Min } from 'class-validator';
import { MembershipStatus } from '@prisma/client';
import { PaginationQuery } from '../../common/pagination';

export class CreateMembershipDto {
  @IsUUID()
  studentId: string;

  @IsUUID()
  planId: string;

  @IsDateString()
  startDate: string;

  @IsOptional() @IsDateString()
  endDate?: string;

  /** Valor negociado; se omitido usa o preço do plano. */
  @IsOptional() @IsInt() @Min(0)
  priceCents?: number;
}

export class ListMembershipsQuery extends PaginationQuery {
  @IsOptional() @IsEnum(MembershipStatus)
  status?: MembershipStatus;
}
