import { PartialType } from '@nestjs/mapped-types';
import { Type } from 'class-transformer';
import { ArrayUnique, IsArray, IsDateString, IsEmail, IsEnum, IsInt, IsOptional, IsString, IsUUID, Matches, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { StudentStatus } from '@prisma/client';
import { PaginationQuery } from '../../common/pagination';

export class CreateStudentDto {
  @IsString() @MinLength(2) @MaxLength(120)
  name: string;

  @IsOptional() @IsEmail()
  email?: string;

  @IsOptional() @IsString() @MaxLength(30)
  phone?: string;

  @IsOptional() @Matches(/^\d{11}$/, { message: 'CPF deve conter 11 dígitos' })
  cpf?: string;

  @IsOptional() @IsDateString()
  birthDate?: string;

  @IsOptional() @IsEnum(StudentStatus)
  status?: StudentStatus;

  @IsOptional() @IsString() @MaxLength(2000)
  notes?: string;
}

export class RegistrationMembershipDto {
  @IsUUID()
  planId: string;

  @IsDateString()
  startDate: string;

  @IsOptional() @IsInt() @Min(0)
  priceCents?: number;
}

export class RegisterStudentDto extends CreateStudentDto {
  @IsOptional() @IsArray() @ArrayUnique((membership: RegistrationMembershipDto) => membership.planId)
  @ValidateNested({ each: true }) @Type(() => RegistrationMembershipDto)
  memberships?: RegistrationMembershipDto[];
}

export class AppAccessDto {
  /** Se omitida, uma senha provisória é gerada. */
  @IsOptional() @IsString() @MinLength(8) @MaxLength(128)
  password?: string;
}

export class UpdateStudentDto extends PartialType(CreateStudentDto) {}

export class ListStudentsQuery extends PaginationQuery {
  @IsOptional() @IsEnum(StudentStatus)
  status?: StudentStatus;
}
