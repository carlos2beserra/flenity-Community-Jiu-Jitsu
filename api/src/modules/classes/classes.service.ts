import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { addDays, zonedDayStart, zonedToday } from '../../domain/dates';
import { CreateClassDto, UpdateClassDto } from './classes.dto';

@Injectable()
export class ClassesService {
  constructor(private readonly prisma: PrismaService) {}

  list(academyId: string) {
    return this.prisma.classSchedule.findMany({
      where: { academyId },
      include: { modality: { select: { id: true, name: true } }, instructor: { select: { id: true, name: true } } },
      orderBy: [{ weekday: 'asc' }, { startTime: 'asc' }],
    });
  }

  /** Turmas do dia com a contagem de presenças registradas hoje. */
  async today(academyId: string) {
    const today = zonedToday();
    const dayStart = zonedDayStart(today);
    const classes = await this.prisma.classSchedule.findMany({
      where: { academyId, weekday: today.getUTCDay() },
      include: {
        modality: { select: { id: true, name: true } },
        instructor: { select: { id: true, name: true } },
        _count: { select: { checkIns: { where: { checkedAt: { gte: dayStart } } } } },
      },
      orderBy: { startTime: 'asc' },
    });
    return classes.map(({ _count, ...cls }) => ({ ...cls, checkInsToday: _count.checkIns }));
  }

  /** Quem fez check-in hoje na turma (chamada do professor). */
  async attendance(academyId: string, id: string) {
    const cls = await this.prisma.classSchedule.findFirstOrThrow({
      where: { id, academyId },
      include: { modality: { select: { id: true, name: true } }, instructor: { select: { id: true, name: true } } },
    });
    const today = zonedToday();
    const checkIns = await this.prisma.checkIn.findMany({
      where: { classId: id, checkedAt: { gte: zonedDayStart(today), lt: zonedDayStart(addDays(today, 1)) } },
      include: { student: { select: { id: true, name: true } } },
      orderBy: { checkedAt: 'asc' },
    });
    return { class: cls, checkIns };
  }

  async create(academyId: string, dto: CreateClassDto) {
    await this.assertRelations(academyId, dto);
    return this.prisma.classSchedule.create({ data: { ...dto, academyId } });
  }

  async update(academyId: string, id: string, dto: UpdateClassDto) {
    const current = await this.prisma.classSchedule.findFirstOrThrow({ where: { id, academyId } });
    await this.assertRelations(academyId, { ...current, ...dto });
    return this.prisma.classSchedule.update({ where: { id }, data: dto });
  }

  async remove(academyId: string, id: string) {
    await this.prisma.classSchedule.findFirstOrThrow({ where: { id, academyId } });
    await this.prisma.classSchedule.delete({ where: { id } });
  }

  private async assertRelations(
    academyId: string,
    dto: { modalityId: string; instructorId?: string | null; startTime: string; endTime: string },
  ) {
    if (dto.endTime <= dto.startTime) throw new BadRequestException('Horário final deve ser após o inicial');
    await this.prisma.modality.findFirstOrThrow({ where: { id: dto.modalityId, academyId } });
    if (dto.instructorId) await this.prisma.user.findFirstOrThrow({ where: { id: dto.instructorId, academyId } });
  }
}
