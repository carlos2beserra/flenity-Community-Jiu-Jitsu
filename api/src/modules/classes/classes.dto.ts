import { PartialType } from '@nestjs/mapped-types';
import { IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

export class CreateClassDto {
  @IsString() @MinLength(2) @MaxLength(80)
  name: string;

  @IsUUID()
  modalityId: string;

  @IsOptional() @IsUUID()
  instructorId?: string;

  @IsInt() @Min(0) @Max(6)
  weekday: number;

  @Matches(TIME, { message: 'Horário deve estar no formato HH:mm' })
  startTime: string;

  @Matches(TIME, { message: 'Horário deve estar no formato HH:mm' })
  endTime: string;

  @IsOptional() @IsInt() @Min(1) @Max(500)
  capacity?: number;
}

export class UpdateClassDto extends PartialType(CreateClassDto) {}
