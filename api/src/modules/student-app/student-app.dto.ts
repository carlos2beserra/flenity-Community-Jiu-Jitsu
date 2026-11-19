import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { PaginationQuery } from '../../common/pagination';

export class SelfCheckInDto {
  @IsUUID()
  classId: string;
}

export class ChangePasswordDto {
  @IsString() @MinLength(1)
  currentPassword: string;

  @IsString() @MinLength(8) @MaxLength(128)
  newPassword: string;
}

export class StudentHistoryQuery extends PaginationQuery {}
