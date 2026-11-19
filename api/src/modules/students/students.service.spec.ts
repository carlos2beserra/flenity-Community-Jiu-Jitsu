import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PrismaService } from '../../common/prisma.service';
import { RegisterStudentDto } from './students.dto';
import { StudentsService } from './students.service';

describe('RegisterStudentDto', () => {
  it('accepts multiple memberships for a new student', async () => {
    const dto = plainToInstance(RegisterStudentDto, {
      name: 'Ana Silva',
      memberships: [
        { planId: '4c4a7547-5e1f-4590-b5c9-cc4995bd95df', startDate: '2026-11-09' },
        { planId: '821c11ef-ad23-4f4a-9b18-9b689ee8e7c9', startDate: '2026-11-09' },
      ],
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('rejects duplicate plans in the same registration', async () => {
    const dto = plainToInstance(RegisterStudentDto, {
      name: 'Ana Silva',
      memberships: [
        { planId: '4c4a7547-5e1f-4590-b5c9-cc4995bd95df', startDate: '2026-11-09' },
        { planId: '4c4a7547-5e1f-4590-b5c9-cc4995bd95df', startDate: '2026-11-09' },
      ],
    });

    await expect(validate(dto)).resolves.not.toHaveLength(0);
  });
});

describe('StudentsService.create', () => {
  it('creates the student and all selected memberships atomically', async () => {
    const student = {
      id: 'student-1',
      name: 'Ana Silva',
      email: 'ana@example.com',
      status: 'ACTIVE',
    };
    const rankRows: { modalityId: string }[] = [];
    const tx = {
      student: {
        create: jest.fn().mockResolvedValue(student),
        findFirstOrThrow: jest.fn().mockResolvedValue(student),
        update: jest.fn(),
      },
      plan: {
        findFirstOrThrow: jest.fn()
          .mockResolvedValueOnce({
            id: 'plan-jiu-jitsu',
            name: 'Jiu-Jitsu Mensal',
            active: true,
            priceCents: 5000,
            modalities: [{ modality: { id: 'jiu-jitsu', belts: [] } }],
          })
          .mockResolvedValueOnce({
            id: 'plan-jiu-jitsu-no-gi',
            name: 'Jiu-Jitsu No-Gi',
            active: true,
            priceCents: 6000,
            modalities: [{
              modality: {
                id: 'jiu-jitsu',
                belts: [{ id: 'belt-bjj' }],
              },
            }],
          }),
      },
      membership: { create: jest.fn().mockResolvedValue({ id: 'membership-1' }) },
      invoice: { create: jest.fn() },
      studentRank: {
        findMany: jest.fn().mockImplementation(async () => [...rankRows]),
        createMany: jest.fn().mockImplementation(async ({ data }) => {
          rankRows.push(...data.map(({ modalityId }: { modalityId: string }) => ({ modalityId })));
        }),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)),
    };
    const service = new StudentsService(prisma as unknown as PrismaService);

    const result = await service.create('academy-1', {
      name: 'Ana Silva',
      email: 'ana@example.com',
      memberships: [
        { planId: 'plan-jiu-jitsu', startDate: '2026-11-09' },
        { planId: 'plan-jiu-jitsu-no-gi', startDate: '2026-11-09' },
      ],
    });

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.student.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        name: 'Ana Silva',
        account: { create: { email: 'ana@example.com' } },
      }),
    }));
    expect(tx.membership.create).toHaveBeenCalledTimes(2);
    expect(tx.invoice.create).toHaveBeenCalledTimes(2);
    expect(tx.studentRank.createMany).toHaveBeenCalledWith({
      data: [{
        studentId: 'student-1',
        modalityId: 'jiu-jitsu',
        beltId: 'belt-bjj',
        promotedAt: new Date('2026-11-09T00:00:00.000Z'),
      }],
    });
    expect(result).toEqual(student);
  });
});
