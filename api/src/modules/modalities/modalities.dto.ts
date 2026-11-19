import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsHexColor, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';

export class BeltDto {
  @IsString() @MinLength(1) @MaxLength(60)
  name: string;

  @IsOptional() @IsHexColor()
  color?: string;

  @IsInt() @Min(0)
  order: number;

  @IsOptional() @IsInt() @Min(0) @Max(1000)
  minClasses?: number;

  @IsOptional() @IsInt() @Min(0) @Max(10)
  maxDegrees?: number;
}

export class CreateModalityDto {
  @IsString() @MinLength(2) @MaxLength(60)
  name: string;

  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => BeltDto)
  belts?: BeltDto[];
}

export class ReplaceBeltsDto {
  @IsArray() @ArrayMinSize(1) @ValidateNested({ each: true }) @Type(() => BeltDto)
  belts: BeltDto[];
}
