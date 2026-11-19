import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { CreatePlanDto, UpdatePlanDto } from './plans.dto';

const planInclude = { modalities: { include: { modality: true } } } as const;

@Injectable()
export class PlansService {
  constructor(private readonly prisma: PrismaService) {}

  list(academyId: string) {
    return this.prisma.plan.findMany({ where: { academyId }, include: planInclude, orderBy: { priceCents: 'asc' } });
  }

  async create(academyId: string, dto: CreatePlanDto) {
    const { modalityIds, ...data } = dto;
    await this.assertModalitiesBelongToAcademy(academyId, modalityIds);
    return this.prisma.plan.create({
      data: { ...data, academyId, modalities: { create: modalityIds.map((modalityId) => ({ modalityId })) } },
      include: planInclude,
    });
  }

  async update(academyId: string, id: string, dto: UpdatePlanDto) {
    const { modalityIds, ...data } = dto;
    await this.prisma.plan.findFirstOrThrow({ where: { id, academyId } });
    if (modalityIds) await this.assertModalitiesBelongToAcademy(academyId, modalityIds);
    return this.prisma.plan.update({
      where: { id },
      data: {
        ...data,
        ...(modalityIds && { modalities: { deleteMany: {}, create: modalityIds.map((modalityId) => ({ modalityId })) } }),
      },
      include: planInclude,
    });
  }

  private async assertModalitiesBelongToAcademy(academyId: string, modalityIds: string[]) {
    const count = await this.prisma.modality.count({ where: { academyId, id: { in: modalityIds } } });
    if (count !== new Set(modalityIds).size) throw new BadRequestException('Modalidade inválida');
  }
}
