import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { AllAuthenticated, AuthUser, CurrentUser } from '../../common/auth';
import { ChatGateway } from './chat.gateway';
import {
  ChatContactsQuery,
  SendMessageDto,
  StartConversationDto,
} from './chat.dto';
import { ChatService } from './chat.service';

@Controller('chat')
@AllAuthenticated()
export class ChatController {
  constructor(
    private readonly chat: ChatService,
    private readonly gateway: ChatGateway,
  ) {}

  @Get('contacts')
  contacts(
    @CurrentUser() user: AuthUser,
    @Query() query: ChatContactsQuery,
  ) {
    return this.chat.contacts(user, query.search);
  }

  @Get('conversations')
  conversations(@CurrentUser() user: AuthUser) {
    return this.chat.conversations(user);
  }

  @Post('conversations')
  startConversation(
    @CurrentUser() user: AuthUser,
    @Body() dto: StartConversationDto,
  ) {
    return this.chat.startConversation(user, dto.participantId);
  }

  @Get('conversations/:id/messages')
  messages(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.chat.messages(user, id);
  }

  @Post('conversations/:id/messages')
  async sendMessage(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ) {
    const message = await this.chat.sendMessage(user, id, dto);
    this.gateway.publishMessage(message);
    return message;
  }
}
