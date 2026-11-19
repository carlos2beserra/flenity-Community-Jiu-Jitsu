import { Injectable, NotFoundException } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { SkipThrottle } from '@nestjs/throttler';
import { Namespace, Socket } from 'socket.io';
import { AppRole, AuthUser, TokenPayload } from '../../common/auth';
import { ChatService } from './chat.service';

type ChatSocket = Socket & { data: { authUser?: AuthUser } };
type JoinPayload = { conversationId?: unknown };

const acceptedRoles: AppRole[] = [
  'STUDENT',
  'ADMIN',
  'INSTRUCTOR',
  'RECEPTION',
];

@Injectable()
@SkipThrottle()
@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: true },
})
export class ChatGateway implements OnGatewayConnection {
  @WebSocketServer()
  private server!: Namespace;

  constructor(
    private readonly jwt: JwtService,
    private readonly chat: ChatService,
  ) {}

  async handleConnection(client: ChatSocket) {
    try {
      const token = client.handshake.auth?.token;
      if (typeof token !== 'string' || !token) {
        throw new Error('Missing token');
      }
      const payload = await this.jwt.verifyAsync<TokenPayload>(token);
      if (
        typeof payload.sub !== 'string' ||
        typeof payload.academyId !== 'string' ||
        !acceptedRoles.includes(payload.role)
      ) {
        throw new Error('Invalid token payload');
      }
      client.data.authUser = {
        userId: payload.sub,
        academyId: payload.academyId,
        role: payload.role,
      };
      client.emit('chat:ready');
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('chat:join')
  async join(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() payload: JoinPayload,
  ) {
    const user = client.data.authUser;
    if (!user || typeof payload?.conversationId !== 'string') {
      return { ok: false };
    }
    try {
      await this.chat.authorizeConversation(user, payload.conversationId);
      await client.join(this.room(payload.conversationId));
      return { ok: true };
    } catch (error) {
      if (error instanceof NotFoundException) return { ok: false };
      throw error;
    }
  }

  publishMessage(message: { conversationId: string }) {
    this.server
      ?.to(this.room(message.conversationId))
      .emit('chat:message', message);
  }

  private room(conversationId: string) {
    return `conversation:${conversationId}`;
  }
}
