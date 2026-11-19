import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { evaluateCheckIn } from '../../domain/checkin-policy';
import { addDays, startOfWeek, toDateOnly, zonedDayStart, zonedToday } from '../../domain/dates';
import { paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { CreateCheckInDto, ListCheckInsQuery } from './checkins.dto';

@Injectable()
export class CheckInsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(academyId: string, query: ListCheckInsQuery) {
    const day = query.date ? toDateOnly(new Date(query.date)) : zonedToday();
    const where = { academyId, checkedAt: { gte: zonedDayStart(day), lt: zonedDayStart(addDays(day, 1)) } };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.checkIn.findMany({
        where,
        include: {
          student: { select: { id: true, name: true } },
          modality: { select: { id: true, name: true } },
          class: { select: { id: true, name: true, startTime: true } },
        },
        orderBy: { checkedAt: 'desc' },
        ...paginationArgs(query),
      }),
      this.prisma.checkIn.count({ where }),
    ]);
    return toPaginated(items, total, query);
  }

  /** Registra presença aplicando as regras de acesso (plano, inadimplência, limite semanal). */
  async create(academyId: string, dto: CreateCheckInDto) {
    const modalityId = await this.resolveModality(academyId, dto);
    const today = zonedToday();

    const [academy, student, checkInsThisWeek] = await Promise.all([
      this.prisma.academy.findUniqueOrThrow({ where: { id: academyId } }),
      this.prisma.student.findFirstOrThrow({
        where: { id: dto.studentId, academyId },
        include: {
          memberships: { where: { status: 'ACTIVE' }, include: { plan: { include: { modalities: true } } } },
          invoices: { where: { status: 'PENDING' }, select: { status: true, dueDate: true } },
        },
      }),
      this.prisma.checkIn.count({ where: { studentId: dto.studentId, checkedAt: { gte: zonedDayStart(startOfWeek(today)) } } }),
    ]);

    const activeMemberships = student.memberships
      .filter((m) => !m.endDate || m.endDate >= today)
      .map((m) => ({ modalityIds: m.plan.modalities.map((pm) => pm.modalityId), weeklyLimit: m.plan.weeklyLimit }));

    const decision = evaluateCheckIn({
      studentStatus: student.status,
      modalityId,
      activeMemberships,
      pendingInvoices: student.invoices,
      blockOverdueDays: academy.blockOverdueDays,
      checkInsThisWeek,
      today,
    });
    if (!decision.allowed) throw new ForbiddenException(decision.reason);

    if (dto.classId) {
      const duplicate = await this.prisma.checkIn.findFirst({
        where: { studentId: student.id, classId: dto.classId, checkedAt: { gte: zonedDayStart(today) } },
      });
      if (duplicate) throw new ConflictException('Presença já registrada nesta turma hoje');
    }

    return this.prisma.checkIn.create({
      data: { academyId, studentId: student.id, modalityId, classId: dto.classId },
      include: { student: { select: { id: true, name: true } }, modality: { select: { id: true, name: true } } },
    });
  }

  async remove(academyId: string, id: string) {
    await this.prisma.checkIn.findFirstOrThrow({ where: { id, academyId } });
    await this.prisma.checkIn.delete({ where: { id } });
  }

  private async resolveModality(academyId: string, dto: CreateCheckInDto): Promise<string> {
    if (dto.classId) {
      const cls = await this.prisma.classSchedule.findFirstOrThrow({ where: { id: dto.classId, academyId } });
      return cls.modalityId;
    }
    if (!dto.modalityId) throw new BadRequestException('Informe a turma ou a modalidade');
    await this.prisma.modality.findFirstOrThrow({ where: { id: dto.modalityId, academyId } });
    return dto.modalityId;
  }
}
