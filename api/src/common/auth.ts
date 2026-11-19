import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';

/** STUDENT = token do app do aluno; `userId` passa a ser o id do aluno. */
export type AppRole = UserRole | 'STUDENT';
export type AuthUser = { userId: string; academyId: string; role: AppRole };
export type TokenPayload = { sub: string; academyId: string; role: AppRole };

const IS_PUBLIC = 'isPublic';
const ROLES = 'roles';
const STUDENT_ONLY = 'studentOnly';
const ALL_AUTHENTICATED = 'allAuthenticated';

export const Public = () => SetMetadata(IS_PUBLIC, true);
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES, roles);
/** Rotas do app do aluno. Todas as demais rotas autenticadas são exclusivas da equipe. */
export const StudentOnly = () => SetMetadata(STUDENT_ONLY, true);
/** Authenticated routes shared by students and academy staff. */
export const AllAuthenticated = () => SetMetadata(ALL_AUTHENTICATED, true);

export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext): AuthUser => {
  return ctx.switchToHttp().getRequest<{ user: AuthUser }>().user;
});

/** Guard global: valida o JWT (exceto rotas @Public), separa aluno x equipe e aplica @Roles. */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;
    if (context.getType() === 'ws') return true;

    const request = context.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: AuthUser }>();
    const [scheme, token] = (request.headers.authorization ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) throw new UnauthorizedException('Token ausente');

    try {
      const payload = await this.jwt.verifyAsync<TokenPayload>(token);
      request.user = { userId: payload.sub, academyId: payload.academyId, role: payload.role };
    } catch {
      throw new UnauthorizedException('Token inválido ou expirado');
    }

    const isStudent = request.user.role === 'STUDENT';
    const allAuthenticated =
      this.reflector.getAllAndOverride<boolean>(ALL_AUTHENTICATED, targets) ??
      false;
    const studentRoute =
      this.reflector.getAllAndOverride<boolean>(STUDENT_ONLY, targets) ??
      false;
    if (!allAuthenticated && isStudent !== studentRoute) {
      throw new ForbiddenException('Permissão insuficiente');
    }

    const roles = this.reflector.getAllAndOverride<UserRole[] | undefined>(ROLES, targets);
    if (roles && !roles.includes(request.user.role as UserRole)) throw new ForbiddenException('Permissão insuficiente');
    return true;
  }
}
