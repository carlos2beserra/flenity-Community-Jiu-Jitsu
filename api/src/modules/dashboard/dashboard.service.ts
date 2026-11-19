import { Injectable } from '@nestjs/common';
import { addDays, APP_TIMEZONE, zonedDayStart, zonedToday } from '../../domain/dates';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async summary(academyId: string) {
    const tz = APP_TIMEZONE;
    const today = zonedToday();
    // Datas de calendário (comparadas com colunas DATE) e instantes de início no fuso (colunas timestamp).
    const monthStart = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 1));
    const nextMonthStart = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + 1, 1));
    const weekAgo = addDays(today, -6);
    const [todayAt, monthStartAt, nextMonthStartAt, weekAgoAt] = [today, monthStart, nextMonthStart, weekAgo].map((d) => zonedDayStart(d));
    const sixMonthsAgoAt = zonedDayStart(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - 5, 1)));

    const [
      activeStudents,
      activeMemberships,
      paidThisMonth,
      expectedThisMonth,
      overdue,
      checkInsToday,
      leadsOpen,
      checkInsByDay,
      revenueByMonth,
      modalityMix,
    ] = await Promise.all([
      this.prisma.student.count({ where: { academyId, status: 'ACTIVE' } }),
      this.prisma.membership.findMany({
        where: { academyId, status: 'ACTIVE' },
        select: { priceCents: true, plan: { select: { billingCycleMonths: true } } },
      }),
      this.prisma.invoice.aggregate({
        where: { academyId, status: 'PAID', paidAt: { gte: monthStartAt, lt: nextMonthStartAt } },
        _sum: { amountCents: true },
      }),
      this.prisma.invoice.aggregate({
        where: { academyId, status: { in: ['PENDING', 'PAID'] }, dueDate: { gte: monthStart, lt: nextMonthStart } },
        _sum: { amountCents: true },
      }),
      this.prisma.invoice.aggregate({
        where: { academyId, status: 'PENDING', dueDate: { lt: today } },
        _sum: { amountCents: true },
        _count: { _all: true },
      }),
      this.prisma.checkIn.count({ where: { academyId, checkedAt: { gte: todayAt } } }),
      this.prisma.lead.count({ where: { academyId, status: { in: ['NEW', 'CONTACTED', 'TRIAL'] } } }),
      this.prisma.$queryRaw<{ day: Date; total: number }[]>`
        SELECT ("checkedAt" AT TIME ZONE 'UTC' AT TIME ZONE ${tz})::date AS day, count(*)::int AS total
        FROM "CheckIn" WHERE "academyId" = ${academyId} AND "checkedAt" >= ${weekAgoAt}
        GROUP BY 1 ORDER BY 1`,
      this.prisma.$queryRaw<{ month: Date; total: number }[]>`
        SELECT date_trunc('month', "paidAt" AT TIME ZONE 'UTC' AT TIME ZONE ${tz}) AS month, sum("amountCents")::int AS total
        FROM "Invoice" WHERE "academyId" = ${academyId} AND status = 'PAID' AND "paidAt" >= ${sixMonthsAgoAt}
        GROUP BY 1 ORDER BY 1`,
      this.prisma.$queryRaw<{ modality: string; total: number }[]>`
        SELECT m.name AS modality, count(*)::int AS total
        FROM "CheckIn" ci JOIN "Modality" m ON m.id = ci."modalityId"
        WHERE ci."academyId" = ${academyId} AND ci."checkedAt" >= ${monthStartAt}
        GROUP BY 1 ORDER BY 2 DESC`,
    ]);

    // Receita recorrente mensal normalizada (plano trimestral conta 1/3 por mês).
    const mrrCents = Math.round(
      activeMemberships.reduce((sum, m) => sum + m.priceCents / m.plan.billingCycleMonths, 0),
    );

    return {
      activeStudents,
      activeMemberships: activeMemberships.length,
      mrrCents,
      revenueThisMonthCents: paidThisMonth._sum.amountCents ?? 0,
      expectedThisMonthCents: expectedThisMonth._sum.amountCents ?? 0,
      overdueCents: overdue._sum.amountCents ?? 0,
      overdueCount: overdue._count._all,
      checkInsToday,
      leadsOpen,
      checkInsByDay: fillDays(checkInsByDay, weekAgo, 7),
      revenueByMonth: revenueByMonth.map((r) => ({ month: r.month.toISOString().slice(0, 7), totalCents: r.total })),
      modalityMix,
    };
  }

  /** Aniversariantes do mês (para ações de relacionamento). */
  birthdays(academyId: string) {
    const month = zonedToday().getUTCMonth() + 1;
    return this.prisma.$queryRaw<{ id: string; name: string; birthDate: Date; phone: string | null }[]>`
      SELECT id, name, "birthDate", phone FROM "Student"
      WHERE "academyId" = ${academyId} AND status = 'ACTIVE' AND EXTRACT(MONTH FROM "birthDate") = ${month}
      ORDER BY EXTRACT(DAY FROM "birthDate")`;
  }
}

function fillDays(rows: { day: Date; total: number }[], start: Date, days: number) {
  const byDay = new Map(rows.map((r) => [r.day.toISOString().slice(0, 10), r.total]));
  return Array.from({ length: days }, (_, i) => {
    const day = addDays(start, i).toISOString().slice(0, 10);
    return { day, total: byDay.get(day) ?? 0 };
  });
}
