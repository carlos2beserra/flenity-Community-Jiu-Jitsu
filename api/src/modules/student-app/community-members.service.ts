import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../../common/auth';
import { PrismaService } from '../../common/prisma.service';
import { studentAppAccessWhere, Viewer } from './community-views';

/**
 * Descobre (ou cria na primeira visita) o perfil social de quem fez a requisição.
 * Aluno: precisa estar ativo na academia do token. Equipe: precisa pertencer à academia do token.
 */
@Injectable()
export class CommunityMembersService {
  constructor(private readonly prisma: PrismaService) {}

  async resolve(user: AuthUser): Promise<Viewer> {
    const owner = user.role === 'STUDENT' ? await this.studentOwner(user) : await this.staffOwner(user);
    const memberId = await this.upsert(user.academyId, owner);
    return { memberId, academyId: user.academyId };
  }

  private async studentOwner(user: AuthUser) {
    const student = await this.prisma.student.findFirst({
      where: { id: user.userId, academyId: user.academyId, ...studentAppAccessWhere() },
      select: { id: true },
    });
    if (!student) throw new ForbiddenException('Seu acesso à comunidade não está ativo');
    return { studentId: student.id } as const;
  }

  private async staffOwner(user: AuthUser) {
    const staff = await this.prisma.user.findFirst({
      where: { id: user.userId, academyId: user.academyId },
      select: { id: true },
    });
    if (!staff) throw new ForbiddenException('Seu acesso à comunidade não está ativo');
    return { userId: staff.id } as const;
  }

  private async upsert(academyId: string, owner: { studentId: string } | { userId: string }): Promise<string> {
    const where = 'studentId' in owner ? { studentId: owner.studentId } : { userId: owner.userId };
    const existing = await this.prisma.communityMember.findUnique({ where, select: { id: true } });
    if (existing) return existing.id;
    try {
      const created = await this.prisma.communityMember.create({ data: { academyId, ...owner }, select: { id: true } });
      return created.id;
    } catch (error) {
      // Duas requisições simultâneas na primeira visita: a outra criou o perfil.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const member = await this.prisma.communityMember.findUniqueOrThrow({ where, select: { id: true } });
        return member.id;
      }
      throw error;
    }
  }
}
