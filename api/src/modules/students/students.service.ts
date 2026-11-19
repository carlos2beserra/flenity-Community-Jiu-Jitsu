import { BadRequestException, Injectable } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { randomInt } from 'crypto';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { paginationArgs, toPaginated } from '../../common/pagination';
import { createMembershipInTransaction } from '../memberships/memberships.service';
import { AppAccessDto, ListStudentsQuery, RegisterStudentDto, UpdateStudentDto } from './students.dto';

// Sem caracteres ambíguos (0/O, 1/l/I) para facilitar ditar a senha ao aluno.
const PASSWORD_ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(academyId: string, query: ListStudentsQuery) {
    const where: Prisma.StudentWhereInput = {
      academyId,
      status: query.status,
      ...(query.search && {
        OR: [
          { name: { contains: query.search, mode: 'insensitive' } },
          { email: { contains: query.search, mode: 'insensitive' } },
          { cpf: { contains: query.search } },
        ],
      }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.student.findMany({ where, omit: { passwordHash: true }, orderBy: { name: 'asc' }, ...paginationArgs(query) }),
      this.prisma.student.count({ where }),
    ]);
    return toPaginated(items, total, query);
  }

  async get(academyId: string, id: string) {
    const { passwordHash, account, ...student } = await this.prisma.student.findFirstOrThrow({
      where: { id, academyId },
      include: {
        account: { select: { passwordHash: true } },
        memberships: { include: { plan: true }, orderBy: { startDate: 'desc' } },
        invoices: { orderBy: { dueDate: 'desc' }, take: 24 },
        ranks: { include: { belt: true, modality: true }, orderBy: { promotedAt: 'desc' } },
        checkIns: { include: { modality: true }, orderBy: { checkedAt: 'desc' }, take: 20 },
      },
    });
    return {
      ...student,
      hasAppAccess: account?.passwordHash != null || passwordHash !== null,
    };
  }

  /** Libera (ou redefine) o acesso ao app. Retorna a senha uma única vez para a recepção repassar. */
  async grantAppAccess(academyId: string, id: string, dto: AppAccessDto) {
    const student = await this.prisma.student.findFirstOrThrow({ where: { id, academyId } });
    if (!student.email) throw new BadRequestException('Cadastre um e-mail para o aluno antes de liberar o app');
    const password = dto.password ?? Array.from({ length: 8 }, () => PASSWORD_ALPHABET[randomInt(PASSWORD_ALPHABET.length)]).join('');
    const passwordHash = await bcrypt.hash(password, 10);
    await this.prisma.$transaction(async (tx) => {
      const accountId = student.accountId ?? (await tx.studentAccount.create({
        data: { email: student.email, passwordHash },
      })).id;
      await tx.studentAccount.update({
        where: { id: accountId },
        data: { email: student.email, passwordHash },
      });
      await tx.student.updateMany({
        where: { accountId },
        data: { email: student.email, passwordHash },
      });
      await tx.student.update({
        where: { id },
        data: { accountId, email: student.email, passwordHash },
      });
    });
    return { email: student.email, password };
  }

  async revokeAppAccess(academyId: string, id: string) {
    await this.prisma.student.findFirstOrThrow({ where: { id, academyId } });
    await this.prisma.student.update({
      where: { id },
      data: { passwordHash: null, accountId: null },
    });
  }

  create(academyId: string, dto: RegisterStudentDto) {
    const { memberships = [], ...studentData } = dto;
    return this.prisma.$transaction(async (tx) => {
      const student = await tx.student.create({
        data: {
          ...studentData,
          academy: { connect: { id: academyId } },
          account: { create: { email: dto.email ?? null } },
        },
      });

      for (const membership of memberships) {
        await createMembershipInTransaction(tx, academyId, {
          ...membership,
          studentId: student.id,
        });
      }

      return tx.student.findFirstOrThrow({
        where: { id: student.id, academyId },
        omit: { passwordHash: true },
      });
    });
  }

  async update(academyId: string, id: string, dto: UpdateStudentDto) {
    const student = await this.prisma.student.findFirstOrThrow({
      where: { id, academyId },
      select: { accountId: true },
    });
    return this.prisma.$transaction(async (tx) => {
      if (student.accountId && dto.email !== undefined) {
        await tx.studentAccount.update({
          where: { id: student.accountId },
          data: { email: dto.email },
        });
        await tx.student.updateMany({
          where: { accountId: student.accountId },
          data: { email: dto.email },
        });
      }
      return tx.student.update({
        where: { id },
        data: dto,
        omit: { passwordHash: true },
      });
    });
  }

  async remove(academyId: string, id: string) {
    await this.prisma.student.findFirstOrThrow({ where: { id, academyId } });
    await this.prisma.student.delete({ where: { id } });
  }
}
