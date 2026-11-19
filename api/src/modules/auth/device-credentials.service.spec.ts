import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../common/prisma.service';
import { generateDeviceSecret, hashDeviceSecret } from '../../domain/device-credential';
import { DeviceCredentialsService } from './device-credentials.service';

describe('DeviceCredentialsService', () => {
  let prisma: { deviceCredential: Record<string, jest.Mock> };
  let jwt: { signAsync: jest.Mock };
  let service: DeviceCredentialsService;

  beforeEach(() => {
    prisma = {
      deviceCredential: {
        create: jest.fn().mockResolvedValue({ id: 'cred-1', expiresAt: new Date('2026-04-01') }),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        deleteMany: jest.fn(),
      },
    };
    jwt = { signAsync: jest.fn().mockResolvedValue('new-token') };
    service = new DeviceCredentialsService(prisma as unknown as PrismaService, jwt as unknown as JwtService);
  });

  const credential = (secret: string, overrides: Record<string, unknown> = {}) => ({
    id: 'cred-1',
    secretHash: hashDeviceSecret(secret),
    expiresAt: new Date(Date.now() + 86_400_000),
    student: {
      id: 'student-1',
      academyId: 'academy-1',
      status: 'ACTIVE',
      passwordHash: 'hash',
      account: null,
    },
    user: null,
    ...overrides,
  });

  it('stores only the hash and returns the secret once', async () => {
    const result = await service.enroll({ userId: 'student-1', academyId: 'academy-1', role: 'STUDENT' }, { label: ' iPhone ' });

    const data = prisma.deviceCredential.create.mock.calls[0][0].data;
    expect(result.secret).toMatch(/^[a-f0-9]{64}$/);
    expect(data.secretHash).toBe(hashDeviceSecret(result.secret));
    expect(data.secretHash).not.toBe(result.secret);
    expect(data).toMatchObject({ studentId: 'student-1', label: 'iPhone' });
  });

  it('binds staff credentials to the user', async () => {
    await service.enroll({ userId: 'prof-1', academyId: 'academy-1', role: 'INSTRUCTOR' }, {});
    expect(prisma.deviceCredential.create.mock.calls[0][0].data).toMatchObject({ userId: 'prof-1', label: null });
  });

  it('exchanges a valid secret for a token and extends the expiry', async () => {
    const secret = generateDeviceSecret();
    prisma.deviceCredential.findUnique.mockResolvedValue(credential(secret));

    await expect(service.login({ credentialId: 'cred-1', secret })).resolves.toEqual({
      accessToken: 'new-token',
      kind: 'student',
    });
    expect(jwt.signAsync).toHaveBeenCalledWith({ sub: 'student-1', academyId: 'academy-1', role: 'STUDENT' });
    expect(prisma.deviceCredential.update.mock.calls[0][0].data.expiresAt.getTime()).toBeGreaterThan(Date.now());
  });

  it('issues a staff token with the user role', async () => {
    const secret = generateDeviceSecret();
    prisma.deviceCredential.findUnique.mockResolvedValue(
      credential(secret, { student: null, user: { id: 'prof-1', academyId: 'academy-1', role: 'INSTRUCTOR' } }),
    );

    await expect(service.login({ credentialId: 'cred-1', secret })).resolves.toMatchObject({ kind: 'staff' });
    expect(jwt.signAsync).toHaveBeenCalledWith({ sub: 'prof-1', academyId: 'academy-1', role: 'INSTRUCTOR' });
  });

  it('rejects a wrong secret, an unknown credential and an expired one', async () => {
    const secret = generateDeviceSecret();
    prisma.deviceCredential.findUnique.mockResolvedValue(credential(secret));
    await expect(service.login({ credentialId: 'cred-1', secret: generateDeviceSecret() })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );

    prisma.deviceCredential.findUnique.mockResolvedValue(null);
    await expect(service.login({ credentialId: 'cred-1', secret })).rejects.toBeInstanceOf(UnauthorizedException);

    prisma.deviceCredential.findUnique.mockResolvedValue(credential(secret, { expiresAt: new Date(Date.now() - 1000) }));
    await expect(service.login({ credentialId: 'cred-1', secret })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(jwt.signAsync).not.toHaveBeenCalled();
  });

  it('removes the credential when the student lost app access', async () => {
    const secret = generateDeviceSecret();
    prisma.deviceCredential.findUnique.mockResolvedValue(
      credential(secret, {
        student: { id: 's', academyId: 'a', status: 'INACTIVE', passwordHash: 'hash', account: null },
      }),
    );

    await expect(service.login({ credentialId: 'cred-1', secret })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.deviceCredential.delete).toHaveBeenCalledWith({ where: { id: 'cred-1' } });
    expect(jwt.signAsync).not.toHaveBeenCalled();
  });

  it('only the owner revokes a credential', async () => {
    prisma.deviceCredential.deleteMany.mockResolvedValue({ count: 0 });
    await expect(
      service.revoke({ userId: 'intruder', academyId: 'a', role: 'STUDENT' }, 'cred-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.deviceCredential.deleteMany).toHaveBeenCalledWith({ where: { id: 'cred-1', studentId: 'intruder' } });
  });
});
