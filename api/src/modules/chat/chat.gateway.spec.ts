import { NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';
import { AuthUser } from '../../common/auth';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';

type TestSocket = Socket & { data: { authUser?: AuthUser } };

function makeSocket(token = 'valid-token') {
  return {
    handshake: { auth: { token } },
    data: {},
    emit: jest.fn(),
    disconnect: jest.fn(),
    join: jest.fn().mockResolvedValue(undefined),
  } as unknown as TestSocket;
}

describe('ChatGateway', () => {
  const jwt = {
    verifyAsync: jest.fn(),
  };
  const chat = {
    authorizeConversation: jest.fn(),
  };
  let gateway: ChatGateway;

  beforeEach(() => {
    jest.clearAllMocks();
    gateway = new ChatGateway(
      jwt as unknown as JwtService,
      chat as unknown as ChatService,
    );
  });

  it('authenticates a socket with the JWT before announcing readiness', async () => {
    jwt.verifyAsync.mockResolvedValue({
      sub: 'student-1',
      academyId: 'academy-1',
      role: 'STUDENT',
    });
    const client = makeSocket();

    await gateway.handleConnection(client);

    expect(client.data.authUser).toEqual({
      userId: 'student-1',
      academyId: 'academy-1',
      role: 'STUDENT',
    });
    expect(client.emit).toHaveBeenCalledWith('chat:ready');
    expect(client.disconnect).not.toHaveBeenCalled();
  });

  it('disconnects sockets with invalid credentials', async () => {
    jwt.verifyAsync.mockRejectedValue(new Error('Invalid JWT'));
    const client = makeSocket();

    await gateway.handleConnection(client);

    expect(client.disconnect).toHaveBeenCalledWith(true);
    expect(client.emit).not.toHaveBeenCalled();
  });

  it('joins only conversations the authenticated user can access', async () => {
    jwt.verifyAsync.mockResolvedValue({
      sub: 'student-1',
      academyId: 'academy-1',
      role: 'STUDENT',
    });
    const client = makeSocket();
    await gateway.handleConnection(client);
    chat.authorizeConversation.mockResolvedValue(undefined);

    await expect(
      gateway.join(client, { conversationId: 'conversation-1' }),
    ).resolves.toEqual({ ok: true });
    expect(chat.authorizeConversation).toHaveBeenCalledWith(
      {
        userId: 'student-1',
        academyId: 'academy-1',
        role: 'STUDENT',
      },
      'conversation-1',
    );
    expect(client.join).toHaveBeenCalledWith(
      'conversation:conversation-1',
    );
  });

  it('rejects membership in another user conversation', async () => {
    jwt.verifyAsync.mockResolvedValue({
      sub: 'student-1',
      academyId: 'academy-1',
      role: 'STUDENT',
    });
    const client = makeSocket();
    await gateway.handleConnection(client);
    chat.authorizeConversation.mockRejectedValue(
      new NotFoundException('Conversa não encontrada'),
    );

    await expect(
      gateway.join(client, { conversationId: 'private-conversation' }),
    ).resolves.toEqual({ ok: false });
    expect(client.join).not.toHaveBeenCalled();
  });
});
