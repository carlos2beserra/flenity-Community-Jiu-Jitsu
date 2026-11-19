import { Transform } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class GraduationBoardQuery {
  @IsOptional() @IsUUID()
  modalityId?: string;

  @IsOptional() @Transform(({ value }) => value === 'true' || value === true) @IsBoolean()
  eligibleOnly?: boolean;
}

export class PromoteDto {
  @IsUUID()
  studentId: string;

  @IsUUID()
  modalityId: string;

  /** Opcional: força uma faixa/grau específico. Sem isso aplica a próxima graduação da régua. */
  @IsOptional() @IsUUID()
  beltId?: string;

  @IsOptional() @IsInt() @Min(0) @Max(10)
  degree?: number;
}
