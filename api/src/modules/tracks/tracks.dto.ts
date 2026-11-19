import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, IsString, IsUUID, MaxLength, MinLength, ValidateIf } from 'class-validator';
import { TRACK_CATEGORIES, TrackCategoryKey } from '../../domain/tracks';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class TrackBeltQuery {
  @IsOptional() @IsUUID()
  beltId?: string;
}

export class CreateTrackLessonDto {
  @IsUUID()
  beltId: string;

  @IsIn(TRACK_CATEGORIES)
  category: TrackCategoryKey;

  @Transform(trim) @IsString() @MinLength(2) @MaxLength(120)
  title: string;

  @IsOptional() @Transform(trim) @IsString() @MaxLength(4000)
  description?: string;

  @IsOptional() @IsUUID()
  mediaId?: string;

  @IsOptional() @IsBoolean()
  published?: boolean;
}

export class UpdateTrackLessonDto {
  @IsOptional() @IsIn(TRACK_CATEGORIES)
  category?: TrackCategoryKey;

  @IsOptional() @Transform(trim) @IsString() @MinLength(2) @MaxLength(120)
  title?: string;

  @IsOptional() @Transform(trim) @IsString() @MaxLength(4000)
  description?: string;

  /** `null` remove a mídia da lição. */
  @IsOptional() @ValidateIf((_, value) => value !== null) @IsUUID()
  mediaId?: string | null;

  @IsOptional() @IsBoolean()
  published?: boolean;
}

export class MoveTrackLessonDto {
  @IsIn(['up', 'down'])
  direction: 'up' | 'down';
}

export class PublishTrackDto {
  @IsUUID()
  beltId: string;

  @IsOptional() @IsIn(TRACK_CATEGORIES)
  category?: TrackCategoryKey;

  @IsBoolean()
  published: boolean;
}

export class StarterTrackDto {
  @IsUUID()
  beltId: string;
}
