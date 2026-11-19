import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { CreateLeadDto, UpdateLeadDto } from './leads.dto';

@Injectable()
export class LeadsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Funil completo (Kanban). Leads perdidos/convertidos ficam limitados aos 50 mais recentes. */
  async list(academyId: string) {
    const [open, closed] = await Promise.all([
      this.prisma.lead.findMany({ where: { academyId, status: { in: ['NEW', 'CONTACTED', 'TRIAL'] } }, orderBy: { createdAt: 'desc' } }),
      this.prisma.lead.findMany({
        where: { academyId, status: { in: ['CONVERTED', 'LOST'] } },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);
    return [...open, ...closed];
  }

  create(academyId: string, dto: CreateLeadDto) {
    return this.prisma.lead.create({
      data: { ...dto, interest: 'Jiu-Jitsu', academyId },
    });
  }

  async update(academyId: string, id: string, dto: UpdateLeadDto) {
    await this.prisma.lead.findFirstOrThrow({ where: { id, academyId } });
    return this.prisma.lead.update({
      where: { id },
      data: { ...dto, interest: 'Jiu-Jitsu' },
    });
  }

  /** Converte o lead em aluno (sem matrícula; a matrícula é feita em seguida). */
  async convert(academyId: string, id: string) {
    const lead = await this.prisma.lead.findFirstOrThrow({ where: { id, academyId } });
    if (lead.status === 'CONVERTED') throw new BadRequestException('Lead já convertido');

    return this.prisma.$transaction(async (tx) => {
      const student = await tx.student.create({
        data: {
          academy: { connect: { id: academyId } },
          account: { create: { email: lead.email } },
          name: lead.name,
          email: lead.email,
          phone: lead.phone,
          notes: lead.notes,
        },
        omit: { passwordHash: true },
      });
      await tx.lead.update({ where: { id }, data: { status: 'CONVERTED' } });
      return student;
    });
  }
}
