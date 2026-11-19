import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../common/prisma.service';
import { TokenPayload } from '../../common/auth';
import { CreateUserDto, LoginDto, RegisterAcademyDto } from './auth.dto';

const PASSWORD_COST = 10;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async registerAcademy(dto: RegisterAcademyDto) {
    const passwordHash = await bcrypt.hash(dto.password, PASSWORD_COST);
    const user = await this.prisma.user.create({
      data: {
        name: dto.name,
        email: dto.email.toLowerCase(),
        passwordHash,
        role: 'ADMIN',
        academy: {
          create: {
            name: dto.academyName,
            modalities: {
              create: {
                name: 'Jiu-Jitsu',
                belts: {
                  create: [
                    { name: 'Branca', color: '#f5f5f5', order: 0, minClasses: 40, maxDegrees: 4 },
                    { name: 'Azul', color: '#1e5bd6', order: 1, minClasses: 120, maxDegrees: 4 },
                    { name: 'Roxa', color: '#7b2fbf', order: 2, minClasses: 150, maxDegrees: 4 },
                    { name: 'Marrom', color: '#7a4a21', order: 3, minClasses: 150, maxDegrees: 4 },
                    { name: 'Preta', color: '#111111', order: 4, minClasses: 300, maxDegrees: 4 },
                  ],
                },
              },
            },
          },
        },
      },
    });
    return this.issueSession(user);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email.toLowerCase() } });
    const valid = user ? await bcrypt.compare(dto.password, user.passwordHash) : false;
    if (!user || !valid) throw new UnauthorizedException('E-mail ou senha inválidos');
    return this.issueSession(user);
  }

  /** Login do app do aluno. O e-mail pode existir em mais de uma academia, então testa a senha em cada cadastro. */
  async studentLogin(dto: LoginDto) {
    const candidates = await this.prisma.student.findMany({
      where: {
        email: { equals: dto.email.trim(), mode: 'insensitive' },
        status: { not: 'INACTIVE' },
        OR: [
          { passwordHash: { not: null } },
          { account: { is: { passwordHash: { not: null } } } },
        ],
      },
      include: { account: true },
      take: 5,
    });
    for (const student of candidates) {
      const passwordHash = student.account?.passwordHash ?? student.passwordHash;
      if (passwordHash && await bcrypt.compare(dto.password, passwordHash)) {
        const payload: TokenPayload = { sub: student.id, academyId: student.academyId, role: 'STUDENT' };
        return { accessToken: await this.jwt.signAsync(payload), student: { id: student.id, name: student.name, email: student.email } };
      }
    }
    throw new UnauthorizedException('E-mail ou senha inválidos');
  }

  async me(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { id: true, name: true, email: true, role: true, academy: { select: { id: true, name: true, blockOverdueDays: true } } },
    });
  }

  async listUsers(academyId: string) {
    return this.prisma.user.findMany({
      where: { academyId },
      select: { id: true, name: true, email: true, role: true },
      orderBy: { name: 'asc' },
    });
  }

  async createUser(academyId: string, dto: CreateUserDto) {
    const passwordHash = await bcrypt.hash(dto.password, PASSWORD_COST);
    return this.prisma.user.create({
      data: { academyId, name: dto.name, email: dto.email.toLowerCase(), passwordHash, role: dto.role },
      select: { id: true, name: true, email: true, role: true },
    });
  }

  private async issueSession(user: User) {
    const payload: TokenPayload = { sub: user.id, academyId: user.academyId, role: user.role };
    const accessToken = await this.jwt.signAsync(payload);
    return { accessToken, user: { id: user.id, name: user.name, email: user.email, role: user.role } };
  }
}
