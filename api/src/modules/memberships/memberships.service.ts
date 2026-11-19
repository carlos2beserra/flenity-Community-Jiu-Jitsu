import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { toDateOnly, zonedToday } from '../../domain/dates';
import { paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { CreateMembershipDto, ListMembershipsQuery } from './memberships.dto';

@Injectable()
export class MembershipsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(academyId: string, query: ListMembershipsQuery) {
    const where: Prisma.MembershipWhereInput = {
      academyId,
      status: query.status,
      ...(query.search && { student: { name: { contains: query.search, mode: 'insensitive' } } }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.membership.findMany({
        where,
        include: { student: { select: { id: true, name: true } }, plan: { select: { id: true, name: true, billingCycleMonths: true } } },
        orderBy: { startDate: 'desc' },
        ...paginationArgs(query),
      }),
      this.prisma.membership.count({ where }),
    ]);
    return toPaginated(items, total, query);
  }

  /**
   * Matricula o aluno: cria o contrato, a primeira cobrança e a graduação inicial
   * (primeira faixa) nas modalidades do plano em que ele ainda não tem graduação.
   */
  async create(academyId: string, dto: CreateMembershipDto) {
    return this.prisma.$transaction((tx) => createMembershipInTransaction(tx, academyId, dto));
  }

  /** Cancela o contrato e as cobranças pendentes ainda não vencidas. */
  async cancel(academyId: string, id: string) {
    const membership = await this.prisma.membership.findFirstOrThrow({ where: { id, academyId } });
    if (membership.status !== 'ACTIVE') throw new BadRequestException('Matrícula não está ativa');
    const today = zonedToday();

    return this.prisma.$transaction(async (tx) => {
      await tx.invoice.updateMany({
        where: { membershipId: id, status: 'PENDING', dueDate: { gte: today } },
        data: { status: 'CANCELED' },
      });
      return tx.membership.update({ where: { id }, data: { status: 'CANCELED', endDate: today } });
    });
  }
}

export async function createMembershipInTransaction(
  tx: Prisma.TransactionClient,
  academyId: string,
  dto: CreateMembershipDto,
) {
  const [student, plan] = await Promise.all([
    tx.student.findFirstOrThrow({ where: { id: dto.studentId, academyId } }),
    tx.plan.findFirstOrThrow({
      where: { id: dto.planId, academyId },
      include: { modalities: { include: { modality: { include: { belts: { orderBy: { order: 'asc' }, take: 1 } } } } } },
    }),
  ]);
  if (!plan.active) throw new BadRequestException('Plano inativo');

  const startDate = toDateOnly(new Date(dto.startDate));
  const endDate = dto.endDate ? toDateOnly(new Date(dto.endDate)) : null;
  if (endDate && endDate <= startDate) throw new BadRequestException('Data final deve ser após o início');
  const priceCents = dto.priceCents ?? plan.priceCents;

  const membership = await tx.membership.create({
    data: { academyId, studentId: student.id, planId: plan.id, priceCents, startDate, endDate },
  });
  await tx.invoice.create({
    data: {
      academyId,
      studentId: student.id,
      membershipId: membership.id,
      description: `${plan.name} - 1ª parcela`,
      amountCents: priceCents,
      dueDate: startDate,
    },
  });

  const rankedModalities = await tx.studentRank.findMany({
    where: { studentId: student.id },
    select: { modalityId: true },
    distinct: ['modalityId'],
  });
  const ranked = new Set(rankedModalities.map((rank) => rank.modalityId));
  const initialRanks = plan.modalities
    .filter(({ modality }) => !ranked.has(modality.id) && modality.belts.length > 0)
    .map(({ modality }) => ({
      studentId: student.id,
      modalityId: modality.id,
      beltId: modality.belts[0].id,
      promotedAt: startDate,
    }));
  if (initialRanks.length) await tx.studentRank.createMany({ data: initialRanks });

  if (student.status === 'INACTIVE') {
    await tx.student.update({ where: { id: student.id }, data: { status: 'ACTIVE' } });
  }
  return membership;
}
