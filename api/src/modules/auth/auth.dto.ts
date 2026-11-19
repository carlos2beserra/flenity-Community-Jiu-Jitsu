import { IsEmail, IsEnum, IsOptional, IsString, IsUUID, Matches, MaxLength, MinLength } from 'class-validator';
import { UserRole } from '@prisma/client';

export class RegisterAcademyDto {
  @IsString() @MinLength(2) @MaxLength(120)
  academyName: string;

  @IsString() @MinLength(2) @MaxLength(120)
  name: string;

  @IsEmail()
  email: string;

  @IsString() @MinLength(8) @MaxLength(128)
  password: string;
}

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString() @MinLength(1)
  password: string;
}

export class StudentLoginDto extends LoginDto {}

export class CreateUserDto {
  @IsString() @MinLength(2) @MaxLength(120)
  name: string;

  @IsEmail()
  email: string;

  @IsString() @MinLength(8) @MaxLength(128)
  password: string;

  @IsEnum(UserRole)
  role: UserRole;
}

export class DeviceCredentialDto {
  /** Nome do aparelho exibido ao usuário (ex.: "iPhone de Ana"). */
  @IsOptional() @IsString() @MaxLength(80)
  label?: string;
}

export class DeviceLoginDto {
  @IsUUID('4')
  credentialId: string;

  @IsString() @Matches(/^[a-f0-9]{64}$/)
  secret: string;
}
