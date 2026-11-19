import {
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class ChatContactsQuery {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}

export class StartConversationDto {
  @IsString()
  @MinLength(1)
  participantId: string;
}

export class SendMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content: string;
}
