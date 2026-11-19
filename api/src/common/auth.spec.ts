import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { AppRole, AuthGuard } from './auth';

type Meta = {
  isPublic?: boolean;
  roles?: string[];
  studentOnly?: boolean;
  allAuthenticated?: boolean;
};

function setup(role: AppRole | null, meta: Meta = {}) {
  const jwt = { verifyAsync: jest.fn().mockResolvedValue({ sub: 'u1', academyId: 'a1', role }) } as unknown as JwtService;
  const reflector = { getAllAndOverride: jest.fn((key: keyof Meta) => meta[key]) } as unknown as Reflector;
  const request = { headers: role ? { authorization: 'Bearer token' } : {} } as { headers: Record<string, string>; user?: unknown };
  const context = {
    getHandler: () => null,
    getClass: () => null,
    getType: () => 'http',
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  return { guard: new AuthGuard(jwt, reflector), context, request };
}

describe('AuthGuard', () => {
  it('libera rota pública sem token', async () => {
    const { guard, context } = setup(null, { isPublic: true });
    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it('deixa a autenticação WebSocket para o gateway', async () => {
    const { guard, context } = setup(null);
    jest.spyOn(context, 'getType').mockReturnValue('ws');

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it('exige token em rota protegida', async () => {
    const { guard, context } = setup(null);
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('bloqueia token de aluno em rotas da equipe (ex.: listagem de alunos)', async () => {
    const { guard, context } = setup('STUDENT');
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('bloqueia token da equipe nas rotas do app do aluno', async () => {
    const { guard, context } = setup('ADMIN', { studentOnly: true });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('libera aluno nas rotas do aluno e popula request.user', async () => {
    const { guard, context, request } = setup('STUDENT', { studentOnly: true });
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.user).toEqual({ userId: 'u1', academyId: 'a1', role: 'STUDENT' });
  });

  it('permite acesso autenticado de aluno e equipe em rotas compartilhadas', async () => {
    const student = setup('STUDENT', { allAuthenticated: true });
    const staff = setup('INSTRUCTOR', { allAuthenticated: true });

    await expect(student.guard.canActivate(student.context)).resolves.toBe(true);
    await expect(staff.guard.canActivate(staff.context)).resolves.toBe(true);
  });

  it('aplica @Roles para a equipe', async () => {
    const { guard, context } = setup('INSTRUCTOR', { roles: ['ADMIN'] });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(ForbiddenException);
  });
});
