import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../../common/prisma.service';
import { TokenPayload } from '../../common/auth';
import { CommunityInviteDto } from './community.dto';
import { visibleMemberWhere } from './community-views';

const inviteTokenHash = (token: string) =>
  createHash('sha256').update(token).digest('hex');

@Injectable()
export class CommunityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async communities(studentId: string, academyId: string) {
    const current = await this.prisma.student.findFirstOrThrow({
      where: { id: studentId, academyId },
      select: { accountId: true },
    });
    if (!current.accountId) {
      throw new BadRequestException('Esta conta ainda não está vinculada a uma comunidade');
    }

    const profiles = await this.prisma.student.findMany({
      where: { accountId: current.accountId, status: 'ACTIVE' },
      select: {
        id: true,
        academyId: true,
        academy: { select: { name: true } },
        memberships: {
          where: { status: 'ACTIVE' },
          select: { plan: { select: { name: true } } },
        },
      },
      orderBy: { academy: { name: 'asc' } },
    });
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    return Promise.all(
      profiles.map(async (profile) => {
        const [memberCount, postsThisWeek] = await Promise.all([
          this.prisma.communityMember.count({ where: visibleMemberWhere(profile.academyId) }),
          this.prisma.communityPost.count({
            where: { academyId: profile.academyId, createdAt: { gte: weekAgo } },
          }),
        ]);
        return {
          id: profile.id,
          academyId: profile.academyId,
          name: profile.academy.name,
          plans: [...new Set(profile.memberships.map((membership) => membership.plan.name))],
          isCurrent: profile.id === studentId,
          memberCount,
          postsThisWeek,
        };
      }),
    );
  }

  async switchCommunity(studentId: string, academyId: string, targetId: string) {
    const current = await this.prisma.student.findFirstOrThrow({
      where: { id: studentId, academyId },
      select: { accountId: true },
    });
    if (!current.accountId) {
      throw new BadRequestException('Esta conta ainda não está vinculada a uma comunidade');
    }
    const target = await this.prisma.student.findFirst({
      where: { id: targetId, accountId: current.accountId, status: 'ACTIVE' },
      select: { id: true, academyId: true, name: true },
    });
    if (!target) throw new NotFoundException('Comunidade não encontrada');

    const payload: TokenPayload = {
      sub: target.id,
      academyId: target.academyId,
      role: 'STUDENT',
    };
    return {
      accessToken: await this.jwt.signAsync(payload),
      student: target,
    };
  }

  async acceptInvite(studentId: string, academyId: string, dto: CommunityInviteDto) {
    const current = await this.prisma.student.findFirstOrThrow({
      where: { id: studentId, academyId },
      include: { account: true },
    });
    if (!current.accountId || !current.account?.email) {
      throw new BadRequestException('Sua conta precisa ter um e-mail para aceitar convites');
    }

    const invite = await this.prisma.communityInvite.findUnique({
      where: { tokenHash: inviteTokenHash(dto.token.trim()) },
      include: {
        student: {
          select: { id: true, academyId: true, accountId: true, email: true, status: true },
        },
      },
    });
    if (!invite || invite.acceptedAt || invite.expiresAt <= new Date()) {
      throw new NotFoundException('Convite inválido, expirado ou já utilizado');
    }
    if (
      invite.student.status !== 'ACTIVE' ||
      invite.student.email?.trim().toLowerCase() !== current.account.email.trim().toLowerCase()
    ) {
      throw new BadRequestException('Este convite não corresponde ao e-mail da sua conta');
    }

    try {
      await this.prisma.$transaction(async (tx) => {
        const alreadyInAcademy = await tx.student.findFirst({
          where: {
            accountId: current.accountId!,
            academyId: invite.student.academyId,
          },
          select: { id: true },
        });
        if (alreadyInAcademy && alreadyInAcademy.id !== invite.student.id) {
          throw new ConflictException('Sua conta já faz parte desta academia');
        }

        const claimed = await tx.communityInvite.updateMany({
          where: { id: invite.id, acceptedAt: null, expiresAt: { gt: new Date() } },
          data: { acceptedAt: new Date() },
        });
        if (claimed.count !== 1) {
          throw new NotFoundException('Convite inválido, expirado ou já utilizado');
        }
        const linked = await tx.student.updateMany({
          where: { id: invite.student.id, accountId: invite.student.accountId },
          data: { accountId: current.accountId },
        });
        if (linked.count !== 1) {
          throw new ConflictException('Este cadastro foi vinculado a outra conta');
        }
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Sua conta já faz parte desta academia');
      }
      throw error;
    }

    return { accepted: true, academyId: invite.student.academyId };
  }

  async createInvite(academyId: string, studentId: string) {
    const student = await this.prisma.student.findFirstOrThrow({
      where: { id: studentId, academyId },
      select: { id: true, email: true, status: true },
    });
    if (student.status !== 'ACTIVE') {
      throw new BadRequestException('Somente alunos ativos podem receber convites');
    }
    if (!student.email) throw new BadRequestException('Cadastre um e-mail para o aluno');

    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
    await this.prisma.communityInvite.create({
      data: {
        academyId,
        studentId,
        tokenHash: inviteTokenHash(token),
        expiresAt,
      },
    });
    return { token, expiresAt };
  }
}
