import { ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../common/prisma.service';
import { CommunityService } from './community.service';

describe('CommunityService', () => {
  let prisma: {
    student: Record<string, jest.Mock>;
    communityInvite: Record<string, jest.Mock>;
    communityPost: Record<string, jest.Mock>;
    communityMember: Record<string, jest.Mock>;
    $transaction: jest.Mock;
  };
  let jwt: { signAsync: jest.Mock };
  let service: CommunityService;

  beforeEach(() => {
    prisma = {
      student: {
        findFirstOrThrow: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      communityMember: { count: jest.fn().mockResolvedValue(0) },
      communityInvite: {
        findUnique: jest.fn(),
        updateMany: jest.fn(),
        create: jest.fn(),
      },
      communityPost: { count: jest.fn().mockResolvedValue(0) },
      $transaction: jest.fn(),
    };
    jwt = { signAsync: jest.fn().mockResolvedValue('new-token') };
    service = new CommunityService(
      prisma as unknown as PrismaService,
      jwt as unknown as JwtService,
    );
  });

  it('only lists profiles linked to the authenticated student account', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({ accountId: 'account-1' });
    prisma.student.findMany.mockResolvedValue([
      {
        id: 'student-1',
        academyId: 'academy-1',
        academy: { name: 'Jiu-Jitsu' },
        memberships: [{ plan: { name: 'Jiu-Jitsu Adulto' } }],
      },
      {
        id: 'student-2',
        academyId: 'academy-2',
        academy: { name: 'Crossfit' },
        memberships: [{ plan: { name: 'Crossfit 3x' } }],
      },
    ]);

    await expect(service.communities('student-1', 'academy-1')).resolves.toEqual([
      {
        id: 'student-1',
        academyId: 'academy-1',
        name: 'Jiu-Jitsu',
        plans: ['Jiu-Jitsu Adulto'],
        isCurrent: true,
        memberCount: 0,
        postsThisWeek: 0,
      },
      {
        id: 'student-2',
        academyId: 'academy-2',
        name: 'Crossfit',
        plans: ['Crossfit 3x'],
        isCurrent: false,
        memberCount: 0,
        postsThisWeek: 0,
      },
    ]);
    expect(prisma.student.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { accountId: 'account-1', status: 'ACTIVE' } }),
    );
  });

  it('counts community members and weekly posts per academy', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({ accountId: 'account-1' });
    prisma.student.findMany.mockResolvedValue([
      { id: 'student-1', academyId: 'academy-1', academy: { name: 'Centro' }, memberships: [] },
    ]);
    prisma.communityMember.count.mockResolvedValue(42);
    prisma.communityPost.count.mockResolvedValue(7);

    const [community] = await service.communities('student-1', 'academy-1');

    expect(community).toMatchObject({ memberCount: 42, postsThisWeek: 7 });
    expect(prisma.communityMember.count.mock.calls[0][0].where).toMatchObject({ academyId: 'academy-1' });
    expect(prisma.communityPost.count.mock.calls[0][0].where.academyId).toBe('academy-1');
  });

  it('switches context only to another profile linked to the same account', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({ accountId: 'account-1' });
    prisma.student.findFirst.mockResolvedValue({
      id: 'student-2',
      academyId: 'academy-2',
      name: 'Ana',
    });

    await expect(
      service.switchCommunity('student-1', 'academy-1', 'student-2'),
    ).resolves.toEqual({
      accessToken: 'new-token',
      student: { id: 'student-2', academyId: 'academy-2', name: 'Ana' },
    });
    expect(jwt.signAsync).toHaveBeenCalledWith({
      sub: 'student-2',
      academyId: 'academy-2',
      role: 'STUDENT',
    });
    expect(prisma.student.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'student-2', accountId: 'account-1', status: 'ACTIVE' },
      }),
    );
  });

  it('rejects invitations sent to a different email', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({
      accountId: 'account-1',
      account: { email: 'ana@example.com' },
    });
    prisma.communityInvite.findUnique.mockResolvedValue({
      id: 'invite-1',
      acceptedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      student: {
        id: 'student-2',
        academyId: 'academy-2',
        accountId: 'account-2',
        email: 'other@example.com',
        status: 'ACTIVE',
      },
    });

    await expect(
      service.acceptInvite('student-1', 'academy-1', { token: 'a'.repeat(64) }),
    ).rejects.toThrow('Este convite não corresponde ao e-mail da sua conta');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('claims a valid invite and links the target academy student to the account', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({
      accountId: 'account-1',
      account: { email: 'ana@example.com' },
    });
    prisma.communityInvite.findUnique.mockResolvedValue({
      id: 'invite-1',
      acceptedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      student: {
        id: 'student-2',
        academyId: 'academy-2',
        accountId: 'account-2',
        email: ' ANA@example.com ',
        status: 'ACTIVE',
      },
    });
    const tx = {
      student: {
        findFirst: jest.fn().mockResolvedValue(null),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      communityInvite: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    prisma.$transaction.mockImplementation((work: (client: typeof tx) => unknown) => work(tx));

    await expect(
      service.acceptInvite('student-1', 'academy-1', { token: 'a'.repeat(64) }),
    ).resolves.toEqual({ accepted: true, academyId: 'academy-2' });
    expect(tx.student.updateMany).toHaveBeenCalledWith({
      where: { id: 'student-2', accountId: 'account-2' },
      data: { accountId: 'account-1' },
    });
  });

  it('does not add a second profile for an academy already linked to the account', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({
      accountId: 'account-1',
      account: { email: 'ana@example.com' },
    });
    prisma.communityInvite.findUnique.mockResolvedValue({
      id: 'invite-1',
      acceptedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      student: {
        id: 'student-2',
        academyId: 'academy-2',
        accountId: 'account-2',
        email: 'ana@example.com',
        status: 'ACTIVE',
      },
    });
    const tx = {
      student: {
        findFirst: jest.fn().mockResolvedValue({ id: 'other-student' }),
        updateMany: jest.fn(),
      },
      communityInvite: { updateMany: jest.fn() },
    };
    prisma.$transaction.mockImplementation((work: (client: typeof tx) => unknown) => work(tx));

    await expect(
      service.acceptInvite('student-1', 'academy-1', { token: 'a'.repeat(64) }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.communityInvite.updateMany).not.toHaveBeenCalled();
  });

  it('stores only a hash of generated invitation tokens', async () => {
    prisma.student.findFirstOrThrow.mockResolvedValue({
      id: 'student-1',
      email: 'ana@example.com',
      status: 'ACTIVE',
    });

    const invite = await service.createInvite('academy-1', 'student-1');
    const create = prisma.communityInvite.create.mock.calls[0][0];
    expect(invite.token).toMatch(/^[a-f0-9]{64}$/);
    expect(create.data.tokenHash).not.toBe(invite.token);
    expect(create.data.academyId).toBe('academy-1');
  });
});
