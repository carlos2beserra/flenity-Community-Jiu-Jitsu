import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { ModalitiesService } from './modalities.service';

describe('ModalitiesService', () => {
  const prisma = {
    modality: {
      findFirst: jest.fn(),
      create: jest.fn(),
      findFirstOrThrow: jest.fn(),
      delete: jest.fn(),
      findMany: jest.fn(),
    },
    $transaction: jest.fn(),
  };
  const service = new ModalitiesService(prisma as unknown as PrismaService);

  beforeEach(() => jest.clearAllMocks());

  it('rejects creation of modalities outside Jiu-Jitsu', () => {
    expect(() =>
      service.create('academy-1', { name: 'Muay Thai', belts: [] }),
    ).toThrow(BadRequestException);
    expect(prisma.modality.create).not.toHaveBeenCalled();
  });

  it('does not allow removal of the academy Jiu-Jitsu modality', async () => {
    prisma.modality.findFirstOrThrow.mockResolvedValue({ id: 'bjj' });
    await expect(service.remove('academy-1', 'bjj')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.modality.delete).not.toHaveBeenCalled();
  });
});
