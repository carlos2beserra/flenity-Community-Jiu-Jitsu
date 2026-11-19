import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AuthUser, TokenPayload } from '../../common/auth';
import { PrismaService } from '../../common/prisma.service';
import {
  deviceCredentialExpiry,
  deviceSecretMatches,
  generateDeviceSecret,
  hashDeviceSecret,
} from '../../domain/device-credential';
import { DeviceCredentialDto, DeviceLoginDto } from './auth.dto';

const INVALID = 'Entrada com biometria expirada. Entre com sua senha para ativar de novo.';

/**
 * Entrada com biometria: o app troca um segredo de aparelho (liberado por digital/Face ID)
 * por um novo token de acesso, sem guardar a senha do usuário no celular.
 */
@Injectable()
export class DeviceCredentialsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async enroll(user: AuthUser, dto: DeviceCredentialDto) {
    const secret = generateDeviceSecret();
    const owner = user.role === 'STUDENT' ? { studentId: user.userId } : { userId: user.userId };
    const credential = await this.prisma.deviceCredential.create({
      data: {
        ...owner,
        secretHash: hashDeviceSecret(secret),
        label: dto.label?.trim() || null,
        expiresAt: deviceCredentialExpiry(new Date()),
      },
      select: { id: true, expiresAt: true },
    });
    // O segredo só sai do servidor nesta resposta; depois disso existe apenas o hash.
    return { credentialId: credential.id, secret, expiresAt: credential.expiresAt };
  }

  async login(dto: DeviceLoginDto) {
    const credential = await this.prisma.deviceCredential.findUnique({
      where: { id: dto.credentialId },
      include: {
        student: { select: { id: true, academyId: true, status: true, passwordHash: true, account: { select: { passwordHash: true } } } },
        user: { select: { id: true, academyId: true, role: true } },
      },
    });
    const now = new Date();
    if (!credential || credential.expiresAt <= now || !deviceSecretMatches(dto.secret, credential.secretHash)) {
      throw new UnauthorizedException(INVALID);
    }

    const payload = this.payloadFor(credential);
    if (!payload) {
      await this.prisma.deviceCredential.delete({ where: { id: credential.id } });
      throw new UnauthorizedException('Seu acesso ao app não está mais ativo. Fale com a sua academia.');
    }

    await this.prisma.deviceCredential.update({
      where: { id: credential.id },
      data: { lastUsedAt: now, expiresAt: deviceCredentialExpiry(now) },
    });
    return {
      accessToken: await this.jwt.signAsync(payload),
      kind: payload.role === 'STUDENT' ? 'student' : 'staff',
    };
  }

  async revoke(user: AuthUser, credentialId: string) {
    const owner = user.role === 'STUDENT' ? { studentId: user.userId } : { userId: user.userId };
    const { count } = await this.prisma.deviceCredential.deleteMany({ where: { id: credentialId, ...owner } });
    if (count === 0) throw new NotFoundException('Credencial não encontrada');
    return { revoked: true };
  }

  private payloadFor(credential: {
    student: { id: string; academyId: string; status: string; passwordHash: string | null; account: { passwordHash: string | null } | null } | null;
    user: { id: string; academyId: string; role: TokenPayload['role'] } | null;
  }): TokenPayload | null {
    const { student, user } = credential;
    if (student) {
      const hasAccess = student.status !== 'INACTIVE' && Boolean(student.account?.passwordHash ?? student.passwordHash);
      return hasAccess ? { sub: student.id, academyId: student.academyId, role: 'STUDENT' } : null;
    }
    return user ? { sub: user.id, academyId: user.academyId, role: user.role } : null;
  }
}
