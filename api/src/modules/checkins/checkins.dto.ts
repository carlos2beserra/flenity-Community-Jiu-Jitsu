import { IsDateString, IsOptional, IsUUID } from 'class-validator';
import { PaginationQuery } from '../../common/pagination';

export class CreateCheckInDto {
  @IsUUID()
  studentId: string;

  /** Turma da agenda; quando informada, a modalidade vem dela. */
  @IsOptional() @IsUUID()
  classId?: string;

  @IsOptional() @IsUUID()
  modalityId?: string;
}

export class ListCheckInsQuery extends PaginationQuery {
  /** YYYY-MM-DD; padrão = hoje */
  @IsOptional() @IsDateString()
  date?: string;
}
