import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { BeltDto, CreateModalityDto } from './modalities.dto';

@Injectable()
export class ModalitiesService {
  constructor(private readonly prisma: PrismaService) {}

  list(academyId: string) {
    return this.prisma.modality.findMany({
      where: { academyId },
      include: { belts: { orderBy: { order: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }

  create(academyId: string, dto: CreateModalityDto) {
    if (!isJiuJitsuName(dto.name)) {
      throw new BadRequestException('A Flenity atende exclusivamente academias de Jiu-Jitsu');
    }
    assertUniqueOrders(dto.belts ?? []);
    return this.createJiuJitsu(academyId, dto);
  }

  private async createJiuJitsu(academyId: string, dto: CreateModalityDto) {
    const existing = await this.prisma.modality.findFirst({ where: { academyId } });
    if (existing) {
      throw new BadRequestException('A modalidade Jiu-Jitsu já está configurada');
    }
    return this.prisma.modality.create({
      data: { academyId, name: dto.name, belts: { create: dto.belts ?? [] } },
      include: { belts: { orderBy: { order: 'asc' } } },
    });
  }

  /** Substitui a régua de faixas. Faixas já usadas em históricos são mantidas e atualizadas pela ordem. */
  async replaceBelts(academyId: string, modalityId: string, belts: BeltDto[]) {
    assertUniqueOrders(belts);
    await this.prisma.modality.findFirstOrThrow({ where: { id: modalityId, academyId } });

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.belt.findMany({ where: { modalityId }, include: { _count: { select: { ranks: true } } } });
      const byOrder = new Map(existing.map((b) => [b.order, b]));
      const keptIds = new Set<string>();

      // Move as ordens existentes para negativo para evitar conflito do @@unique durante a reordenação.
      for (const belt of existing) {
        await tx.belt.update({ where: { id: belt.id }, data: { order: -1 - belt.order } });
      }
      for (const dto of belts) {
        const match = byOrder.get(dto.order);
        if (match) {
          keptIds.add(match.id);
          await tx.belt.update({ where: { id: match.id }, data: dto });
        } else {
          await tx.belt.create({ data: { ...dto, modalityId } });
        }
      }
      const removable = existing.filter((b) => !keptIds.has(b.id));
      if (removable.some((b) => b._count.ranks > 0)) {
        throw new BadRequestException('Não é possível remover faixas que já possuem alunos graduados');
      }
      await tx.belt.deleteMany({ where: { id: { in: removable.map((b) => b.id) } } });
      return tx.belt.findMany({ where: { modalityId }, orderBy: { order: 'asc' } });
    });
  }

  async remove(academyId: string, id: string) {
    await this.prisma.modality.findFirstOrThrow({ where: { id, academyId } });
    throw new BadRequestException('A modalidade Jiu-Jitsu é obrigatória e não pode ser removida');
  }
}

function isJiuJitsuName(name: string) {
  const normalized = name.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().replace(/[^a-z0-9]/g, '');
  return normalized === 'jiujitsu';
}

function assertUniqueOrders(belts: BeltDto[]) {
  if (new Set(belts.map((b) => b.order)).size !== belts.length) {
    throw new BadRequestException('Cada faixa deve ter uma ordem única');
  }
}
