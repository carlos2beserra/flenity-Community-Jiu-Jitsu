import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { PaginationQuery } from '../../common/pagination';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class CommunityInviteDto {
  @IsString()
  @MinLength(32)
  @MaxLength(2048)
  token!: string;
}

export class CommunityPostDto {
  @IsOptional()
  @IsString()
  @MaxLength(2200)
  @Transform(trim)
  content?: string;

  @IsOptional()
  @IsIn(['POST', 'REEL'])
  kind?: 'POST' | 'REEL';

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsUUID('4', { each: true })
  mediaIds?: string[];
}

export class CommunityCommentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  content!: string;
}

export class CommunityFeedQuery extends PaginationQuery {
  /** all = toda a academia; following = só quem eu sigo (e eu). */
  @IsOptional()
  @IsIn(['all', 'following'])
  scope?: 'all' | 'following';

  @IsOptional()
  @IsIn(['POST', 'REEL'])
  kind?: 'POST' | 'REEL';

  @IsOptional()
  @IsUUID('4')
  authorId?: string;
}

export class CommunityProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(150)
  @Transform(trim)
  bio?: string;

  /** null remove a foto de perfil. */
  @IsOptional()
  @ValidateIf((_dto, value) => value !== null)
  @IsUUID('4')
  avatarMediaId?: string | null;
}

export class CommunityStoryDto {
  @IsUUID('4')
  mediaId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  @Transform(trim)
  caption?: string;
}
