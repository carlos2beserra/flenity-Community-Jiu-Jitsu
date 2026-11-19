import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuthUser } from '../../common/auth';
import { PrismaService } from '../../common/prisma.service';
import { SendMessageDto } from './chat.dto';

const staffRoles = ['ADMIN', 'INSTRUCTOR', 'RECEPTION'] as const;

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  async contacts(user: AuthUser, query?: string) {
    const search = query?.trim();
    if (user.role === 'STUDENT') {
      return this.prisma.user.findMany({
        where: {
          academyId: user.academyId,
          role: { in: [...staffRoles] },
          ...(search && { name: { contains: search, mode: 'insensitive' } }),
        },
        select: { id: true, name: true, role: true },
        orderBy: { name: 'asc' },
        take: 50,
      });
    }

    return this.prisma.student.findMany({
      where: {
        academyId: user.academyId,
        status: 'ACTIVE',
        passwordHash: { not: null },
        ...(search && { name: { contains: search, mode: 'insensitive' } }),
      },
      select: { id: true, name: true },
      orderBy: { name: 'asc' },
      take: 50,
    });
  }

  async conversations(user: AuthUser) {
    const conversations = await this.prisma.chatConversation.findMany({
      where: {
        academyId: user.academyId,
        ...(user.role === 'STUDENT'
          ? { studentId: user.userId }
          : { staffId: user.userId }),
      },
      include: {
        student: { select: { id: true, name: true } },
        staff: { select: { id: true, name: true, role: true } },
        messages: {
          take: 1,
          orderBy: { createdAt: 'desc' },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return conversations.map(({ messages, ...conversation }) => ({
      ...conversation,
      lastMessage: messages[0] ?? null,
    }));
  }

  async startConversation(user: AuthUser, participantId: string) {
    const studentId =
      user.role === 'STUDENT' ? user.userId : participantId;
    const staffId = user.role === 'STUDENT' ? participantId : user.userId;

    const [student, staff] = await Promise.all([
      this.prisma.student.findFirst({
        where: {
          id: studentId,
          academyId: user.academyId,
          ...(user.role !== 'STUDENT' && {
            status: 'ACTIVE',
            passwordHash: { not: null },
          }),
        },
        select: { id: true },
      }),
      this.prisma.user.findFirst({
        where: {
          id: staffId,
          academyId: user.academyId,
          role: { in: [...staffRoles] },
        },
        select: { id: true },
      }),
    ]);

    if (!student || !staff) {
      throw new NotFoundException('Contato não encontrado nesta academia');
    }

    return this.prisma.chatConversation.upsert({
      where: { studentId_staffId: { studentId, staffId } },
      create: { academyId: user.academyId, studentId, staffId },
      update: {},
      include: {
        student: { select: { id: true, name: true } },
        staff: { select: { id: true, name: true, role: true } },
      },
    });
  }

  async messages(user: AuthUser, conversationId: string) {
    await this.requireConversation(user, conversationId);
    const messages = await this.prisma.chatMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return messages.reverse();
  }

  async sendMessage(
    user: AuthUser,
    conversationId: string,
    dto: SendMessageDto,
  ) {
    await this.requireConversation(user, conversationId);
    const content = dto.content.trim();
    if (!content) {
      throw new BadRequestException('A mensagem não pode estar vazia');
    }

    return this.prisma.$transaction(async (tx) => {
      const message = await tx.chatMessage.create({
        data: {
          conversationId,
          senderId: user.userId,
          senderRole: user.role === 'STUDENT' ? 'STUDENT' : 'STAFF',
          content,
        },
      });
      await tx.chatConversation.update({
        where: { id: conversationId },
        data: { updatedAt: message.createdAt },
      });
      return message;
    });
  }

  async authorizeConversation(user: AuthUser, conversationId: string) {
    await this.requireConversation(user, conversationId);
  }

  private async requireConversation(user: AuthUser, conversationId: string) {
    const conversation = await this.prisma.chatConversation.findFirst({
      where: {
        id: conversationId,
        academyId: user.academyId,
        ...(user.role === 'STUDENT'
          ? { studentId: user.userId }
          : { staffId: user.userId }),
      },
      select: { id: true },
    });
    if (!conversation) {
      throw new NotFoundException('Conversa não encontrada');
    }
    return conversation;
  }
}
