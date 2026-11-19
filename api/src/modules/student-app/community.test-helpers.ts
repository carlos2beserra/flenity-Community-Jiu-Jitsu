import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/prisma.service';
import { CommunityViews, Viewer } from './community-views';
import { MediaUrlSigner } from './media-url.signer';

/** Usado apenas pelos testes (*.spec.ts): Prisma em memória com jest.fn() por modelo. */
export type PrismaMock = Record<string, Record<string, jest.Mock>> & { $transaction: jest.Mock };

export function createPrismaMock(): PrismaMock {
  const model = () =>
    new Proxy({} as Record<string, jest.Mock>, {
      get: (target, key: string) => (target[key] ??= jest.fn()),
    });
  const models: Record<string, Record<string, jest.Mock>> = {};
  return new Proxy(models, {
    get: (target, key: string) => {
      if (key === '$transaction') return (target.$transaction ??= jest.fn() as never);
      return (target[key] ??= model());
    },
  }) as PrismaMock;
}

export const asPrisma = (mock: PrismaMock) => mock as unknown as PrismaService;

export function testViews() {
  const config = { get: () => undefined, getOrThrow: () => 'jwt-secret' } as unknown as ConfigService;
  return new CommunityViews(new MediaUrlSigner(config));
}

export const viewer = (memberId = 'me', academyId = 'academy-1'): Viewer => ({ memberId, academyId });

/** Perfil de aluno como vem do `authorSelect`. */
export const author = (id: string, name = 'Ana Silva') => ({ id, avatarMediaId: null, student: { name }, user: null });

/** Perfil da equipe como vem do `authorSelect`. */
export const staffAuthor = (id: string, name = 'Mestre Carlos', role = 'INSTRUCTOR') => ({
  id,
  avatarMediaId: null,
  student: null,
  user: { name, role },
});

export function postRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 'post-1',
    academyId: 'academy-1',
    memberId: 'me',
    kind: 'POST',
    content: 'Oss',
    createdAt: new Date('2026-11-17T10:00:00Z'),
    author: author('me'),
    _count: { likes: 0, comments: 0 },
    likes: [],
    saves: [],
    comments: [],
    media: [],
    ...overrides,
  };
}
