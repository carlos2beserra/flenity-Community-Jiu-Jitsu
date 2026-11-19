import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { daysOverdue } from '../../domain/billing';
import { zonedClock, zonedDayStart, zonedToday } from '../../domain/dates';
import { isSelfCheckInOpen } from '../../domain/self-checkin';
import { paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { CheckInsService } from '../checkins/checkins.service';
import { GraduationsService } from '../graduations/graduations.service';
import { ChangePasswordDto, StudentHistoryQuery } from './student-app.dto';

/** Tudo aqui é escopado pelo id do aluno do token: o aluno só enxerga os próprios dados. */
@Injectable()
export class StudentAppService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly checkIns: CheckInsService,
    private readonly graduations: GraduationsService,
  ) {}

  async me(academyId: string, studentId: string) {
    const today = zonedToday();
    const [student, ranks, pendingInvoices, classesThisMonth] = await Promise.all([
      this.prisma.student.findFirstOrThrow({
        where: { id: studentId, academyId },
        select: {
          id: true, name: true, email: true, phone: true, birthDate: true, status: true, createdAt: true,
          academy: { select: { name: true } },
          memberships: {
            where: { status: 'ACTIVE' },
            select: { id: true, startDate: true, endDate: true, priceCents: true, plan: { select: { name: true, weeklyLimit: true } } },
          },
        },
      }),
      this.graduations.board(academyId, { studentId }),
      this.prisma.invoice.findMany({ where: { studentId, status: 'PENDING' }, orderBy: { dueDate: 'asc' } }),
      this.prisma.checkIn.count({
        where: { studentId, checkedAt: { gte: zonedDayStart(new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 1))) } },
      }),
    ]);

    const overdue = pendingInvoices.filter((inv) => daysOverdue(inv, today) > 0);
    return {
      ...student,
      ranks,
      classesThisMonth,
      overdueCount: overdue.length,
      overdueCents: overdue.reduce((sum, inv) => sum + inv.amountCents, 0),
      nextInvoice: pendingInvoices.find((inv) => daysOverdue(inv, today) === 0) ?? null,
    };
  }

  /** Grade semanal das modalidades cobertas pelos planos ativos do aluno. */
  async classes(academyId: string, studentId: string) {
    const memberships = await this.prisma.membership.findMany({
      where: { studentId, academyId, status: 'ACTIVE' },
      select: { plan: { select: { modalities: { select: { modalityId: true } } } } },
    });
    const modalityIds = [...new Set(memberships.flatMap((m) => m.plan.modalities.map((pm) => pm.modalityId)))];
    const clock = zonedClock();

    const [classes, todayCheckIns] = await Promise.all([
      this.prisma.classSchedule.findMany({
        where: { academyId, modalityId: { in: modalityIds } },
        include: { modality: { select: { id: true, name: true } }, instructor: { select: { id: true, name: true } } },
        orderBy: [{ weekday: 'asc' }, { startTime: 'asc' }],
      }),
      this.prisma.checkIn.findMany({
        where: { studentId, checkedAt: { gte: zonedDayStart(zonedToday()) } },
        select: { classId: true },
      }),
    ]);
    const checkedIn = new Set(todayCheckIns.map((c) => c.classId));

    return classes.map((cls) => ({
      ...cls,
      checkInOpen: isSelfCheckInOpen(cls, clock),
      checkedInToday: cls.weekday === clock.weekday && checkedIn.has(cls.id),
    }));
  }

  /** Auto check-in: só na janela da aula; demais regras (plano, atraso, limite) são as mesmas da recepção. */
  async selfCheckIn(academyId: string, studentId: string, classId: string) {
    const cls = await this.prisma.classSchedule.findFirstOrThrow({ where: { id: classId, academyId } });
    if (!isSelfCheckInOpen(cls, zonedClock())) {
      throw new BadRequestException('Check-in liberado de 30 minutos antes do início até o fim da aula');
    }
    return this.checkIns.create(academyId, { studentId, classId });
  }

  async history(academyId: string, studentId: string, query: StudentHistoryQuery) {
    const where = { academyId, studentId };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.checkIn.findMany({
        where,
        include: { modality: { select: { id: true, name: true } }, class: { select: { id: true, name: true, startTime: true } } },
        orderBy: { checkedAt: 'desc' },
        ...paginationArgs(query),
      }),
      this.prisma.checkIn.count({ where }),
    ]);
    return toPaginated(items, total, query);
  }

  invoices(academyId: string, studentId: string) {
    return this.prisma.invoice.findMany({
      where: { academyId, studentId, status: { not: 'CANCELED' } },
      orderBy: { dueDate: 'desc' },
      take: 36,
    });
  }

  async changePassword(academyId: string, studentId: string, dto: ChangePasswordDto) {
    const student = await this.prisma.student.findFirstOrThrow({
      where: { id: studentId, academyId },
      include: { account: true },
    });
    const currentHash = student.account?.passwordHash ?? student.passwordHash;
    if (!currentHash || !(await bcrypt.compare(dto.currentPassword, currentHash))) {
      throw new UnauthorizedException('Senha atual incorreta');
    }
    const passwordHash = await bcrypt.hash(dto.newPassword, 10);
    // Trocar a senha encerra a entrada com biometria em todos os aparelhos da conta.
    const revokeDevices = this.prisma.deviceCredential.deleteMany({
      where: student.accountId ? { student: { accountId: student.accountId } } : { studentId },
    });
    if (student.accountId) {
      await this.prisma.$transaction([
        this.prisma.studentAccount.update({
          where: { id: student.accountId },
          data: { passwordHash },
        }),
        this.prisma.student.updateMany({
          where: { accountId: student.accountId },
          data: { passwordHash },
        }),
        revokeDevices,
      ]);
    } else {
      await this.prisma.$transaction([
        this.prisma.student.update({
          where: { id: studentId },
          data: { passwordHash },
        }),
        revokeDevices,
      ]);
    }
  }
}
