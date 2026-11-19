import { NotFoundException } from '@nestjs/common';
import { AuthUser } from '../../common/auth';
import { PrismaService } from '../../common/prisma.service';
import { ChatService } from './chat.service';

describe('ChatService', () => {
  const studentUser: AuthUser = {
    userId: 'student-1',
    academyId: 'academy-1',
    role: 'STUDENT',
  };
  const staffUser: AuthUser = {
    userId: 'staff-1',
    academyId: 'academy-1',
    role: 'INSTRUCTOR',
  };
  let prisma: {
    user: { findMany: jest.Mock; findFirst: jest.Mock };
    student: { findMany: jest.Mock; findFirst: jest.Mock };
    chatConversation: { findMany: jest.Mock; findFirst: jest.Mock; upsert: jest.Mock };
    chatMessage: { findMany: jest.Mock; create: jest.Mock };
    $transaction: jest.Mock;
  };
  let service: ChatService;

  beforeEach(() => {
    prisma = {
      user: { findMany: jest.fn(), findFirst: jest.fn() },
      student: { findMany: jest.fn(), findFirst: jest.fn() },
      chatConversation: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        upsert: jest.fn(),
      },
      chatMessage: { findMany: jest.fn(), create: jest.fn() },
      $transaction: jest.fn(),
    };
    service = new ChatService(prisma as unknown as PrismaService);
  });

  it('limits student contacts to staff in their own academy', async () => {
    prisma.user.findMany.mockResolvedValue([]);

    await service.contacts(studentUser);

    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          academyId: 'academy-1',
          role: { in: ['ADMIN', 'INSTRUCTOR', 'RECEPTION'] },
        },
      }),
    );
  });

  it('limits staff contacts to active students with app access', async () => {
    prisma.student.findMany.mockResolvedValue([]);

    await service.contacts(staffUser);

    expect(prisma.student.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          academyId: 'academy-1',
          status: 'ACTIVE',
          passwordHash: { not: null },
        },
      }),
    );
  });

  it('does not create a conversation with a student from another academy', async () => {
    prisma.student.findFirst.mockResolvedValue(null);
    prisma.user.findFirst.mockResolvedValue({ id: 'staff-1' });

    await expect(
      service.startConversation(staffUser, 'foreign-student'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.chatConversation.upsert).not.toHaveBeenCalled();
  });

  it('denies access to messages from another participant', async () => {
    prisma.chatConversation.findFirst.mockResolvedValue(null);

    await expect(
      service.messages(studentUser, 'private-conversation'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.chatMessage.findMany).not.toHaveBeenCalled();
  });
});
