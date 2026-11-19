import { PrismaService } from '../../common/prisma.service';
import { LeadsService } from './leads.service';

describe('LeadsService Jiu-Jitsu interest', () => {
  const prisma = {
    lead: {
      create: jest.fn(),
      findFirstOrThrow: jest.fn(),
      update: jest.fn(),
    },
  };
  const service = new LeadsService(prisma as unknown as PrismaService);

  beforeEach(() => jest.clearAllMocks());

  it('sets new leads to Jiu-Jitsu regardless of incoming interest', () => {
    service.create(
      'academy-1',
      { name: 'Pessoa interessada', interest: 'Muay Thai' },
    );

    expect(prisma.lead.create).toHaveBeenCalledWith({
      data: {
        name: 'Pessoa interessada',
        interest: 'Jiu-Jitsu',
        academyId: 'academy-1',
      },
    });
  });

  it('keeps edited leads scoped to Jiu-Jitsu', async () => {
    prisma.lead.findFirstOrThrow.mockResolvedValue({ id: 'lead-1' });

    await service.update(
      'academy-1',
      'lead-1',
      { interest: 'Boxe' },
    );

    expect(prisma.lead.update).toHaveBeenCalledWith({
      where: { id: 'lead-1' },
      data: { interest: 'Jiu-Jitsu' },
    });
  });
});
