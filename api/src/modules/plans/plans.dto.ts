import { PartialType } from '@nestjs/mapped-types';
import { ArrayMinSize, IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';

export class CreatePlanDto {
  @IsString() @MinLength(2) @MaxLength(80)
  name: string;

  @IsInt() @Min(0)
  priceCents: number;

  @IsIn([1, 3, 6, 12])
  billingCycleMonths: number;

  @IsOptional() @IsInt() @Min(1) @Max(14)
  weeklyLimit?: number | null;

  @IsArray() @ArrayMinSize(1) @IsUUID('4', { each: true })
  modalityIds: string[];

  @IsOptional() @IsBoolean()
  active?: boolean;
}

export class UpdatePlanDto extends PartialType(CreatePlanDto) {}
