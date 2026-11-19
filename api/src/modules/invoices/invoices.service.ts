import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { dueDateInMonth } from '../../domain/billing';
import { toDateOnly, zonedToday } from '../../domain/dates';
import { paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { CreateInvoiceDto, GenerateInvoicesDto, ListInvoicesQuery, PayInvoiceDto } from './invoices.dto';

@Injectable()
export class InvoicesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(academyId: string, query: ListInvoicesQuery) {
    const today = zonedToday();
    const overdue = query.status === 'OVERDUE';
    const dueDateFilters: Prisma.InvoiceWhereInput[] = [];
    if (overdue) dueDateFilters.push({ dueDate: { lt: today } });
    if (query.month) dueDateFilters.push({ dueDate: monthRange(query.month) });

    const where: Prisma.InvoiceWhereInput = {
      academyId,
      studentId: query.studentId,
      status: query.status === 'OVERDUE' ? 'PENDING' : query.status,
      AND: dueDateFilters,
      ...(query.search && { student: { name: { contains: query.search, mode: 'insensitive' } } }),
    };

    const [items, total, totals] = await this.prisma.$transaction([
      this.prisma.invoice.findMany({
        where,
        include: { student: { select: { id: true, name: true, phone: true } } },
        orderBy: { dueDate: 'asc' },
        ...paginationArgs(query),
      }),
      this.prisma.invoice.count({ where }),
      this.prisma.invoice.aggregate({ where, _sum: { amountCents: true } }),
    ]);
    return { ...toPaginated(items, total, query), totalAmountCents: totals._sum.amountCents ?? 0 };
  }

  async create(academyId: string, dto: CreateInvoiceDto) {
    await this.prisma.student.findFirstOrThrow({ where: { id: dto.studentId, academyId } });
    return this.prisma.invoice.create({
      data: { ...dto, academyId, dueDate: toDateOnly(new Date(dto.dueDate)) },
    });
  }

  async pay(academyId: string, id: string, dto: PayInvoiceDto) {
    const invoice = await this.prisma.invoice.findFirstOrThrow({ where: { id, academyId } });
    if (invoice.status !== 'PENDING') throw new BadRequestException('Apenas cobranças pendentes podem ser baixadas');
    return this.prisma.invoice.update({
      where: { id },
      data: { status: 'PAID', paymentMethod: dto.paymentMethod, paidAt: dto.paidAt ? new Date(dto.paidAt) : new Date() },
    });
  }

  async cancel(academyId: string, id: string) {
    const invoice = await this.prisma.invoice.findFirstOrThrow({ where: { id, academyId } });
    if (invoice.status !== 'PENDING') throw new BadRequestException('Apenas cobranças pendentes podem ser canceladas');
    return this.prisma.invoice.update({ where: { id }, data: { status: 'CANCELED' } });
  }

  /** Gera as mensalidades do mês para todas as matrículas ativas. Idempotente. */
  async generateForMonth(academyId: string, dto: GenerateInvoicesDto) {
    const memberships = await this.prisma.membership.findMany({
      where: { academyId, status: 'ACTIVE' },
      include: { plan: { select: { name: true, billingCycleMonths: true } } },
    });

    const data = memberships.flatMap((membership) => {
      const dueDate = dueDateInMonth(
        { startDate: membership.startDate, endDate: membership.endDate, billingCycleMonths: membership.plan.billingCycleMonths },
        dto.year,
        dto.month - 1,
      );
      if (!dueDate) return [];
      return [{
        academyId,
        membershipId: membership.id,
        studentId: membership.studentId,
        description: `${membership.plan.name} - ${String(dto.month).padStart(2, '0')}/${dto.year}`,
        amountCents: membership.priceCents,
        dueDate,
      }];
    });

    const result = await this.prisma.invoice.createMany({ data, skipDuplicates: true });
    return { created: result.count, eligible: data.length };
  }
}

function monthRange(month: string) {
  const [year, monthIndex] = month.split('-').map(Number);
  if (!year || !monthIndex || monthIndex > 12) throw new BadRequestException('Mês deve estar no formato YYYY-MM');
  return { gte: new Date(Date.UTC(year, monthIndex - 1, 1)), lt: new Date(Date.UTC(year, monthIndex, 1)) };
}
