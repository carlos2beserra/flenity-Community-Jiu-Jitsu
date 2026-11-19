import { PartialType } from '@nestjs/mapped-types';
import { IsEmail, IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { LeadStatus } from '@prisma/client';

export class CreateLeadDto {
  @IsString() @MinLength(2) @MaxLength(120)
  name: string;

  @IsOptional() @IsString() @MaxLength(30)
  phone?: string;

  @IsOptional() @IsEmail()
  email?: string;

  /** Instagram, indicação, Google, fachada... */
  @IsOptional() @IsString() @MaxLength(60)
  source?: string;

  /** Modalidade de interesse */
  @IsOptional() @IsString() @MaxLength(60)
  interest?: string;

  @IsOptional() @IsEnum(LeadStatus)
  status?: LeadStatus;

  @IsOptional() @IsString() @MaxLength(2000)
  notes?: string;
}

export class UpdateLeadDto extends PartialType(CreateLeadDto) {}
