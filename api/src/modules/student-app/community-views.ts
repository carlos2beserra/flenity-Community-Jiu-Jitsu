import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { handleFromName } from '../../domain/social';
import { PrismaService } from '../../common/prisma.service';
import { MediaUrlSigner } from './media-url.signer';

/** Quem está usando a comunidade: o perfil social (aluno ou equipe) e a academia do token. */
export type Viewer = { memberId: string; academyId: string };

/** Campos públicos de um perfil exibidos na comunidade. */
export const authorSelect = {
  id: true,
  avatarMediaId: true,
  student: { select: { name: true } },
  user: { select: { name: true, role: true } },
} satisfies Prisma.CommunityMemberSelect;

export type AuthorRow = Prisma.CommunityMemberGetPayload<{ select: typeof authorSelect }>;

const STAFF_LABEL: Record<UserRole, string> = {
  INSTRUCTOR: 'Professor',
  ADMIN: 'Equipe',
  RECEPTION: 'Equipe',
};

export function postInclude(viewerId: string) {
  return {
    author: { select: authorSelect },
    _count: { select: { likes: true, comments: true } },
    likes: { where: { memberId: viewerId }, select: { memberId: true }, take: 1 },
    saves: { where: { memberId: viewerId }, select: { memberId: true }, take: 1 },
    comments: {
      orderBy: { createdAt: 'desc' },
      take: 2,
      include: { member: { select: authorSelect } },
    },
    media: {
      orderBy: { position: 'asc' },
      include: { media: { select: { id: true, kind: true } } },
    },
  } satisfies Prisma.CommunityPostInclude;
}

export type PostRow = Prisma.CommunityPostGetPayload<{ include: ReturnType<typeof postInclude> }>;
type CommentRow = Prisma.CommunityPostCommentGetPayload<{
  include: { member: { select: typeof authorSelect } };
}>;

/** Converte linhas do banco para o formato consumido pelo app, com URLs de mídia assinadas. */
@Injectable()
export class CommunityViews {
  constructor(private readonly signer: MediaUrlSigner) {}

  author(author: AuthorRow) {
    const name = author.student?.name ?? author.user?.name ?? 'Membro';
    return {
      id: author.id,
      name,
      handle: handleFromName(name),
      avatarUrl: author.avatarMediaId ? this.signer.url(author.avatarMediaId) : null,
      isStaff: author.user !== null,
      roleLabel: author.user ? STAFF_LABEL[author.user.role] : null,
    };
  }

  media(media: { id: string; kind: 'IMAGE' | 'VIDEO' }) {
    return { id: media.id, kind: media.kind, url: this.signer.url(media.id) };
  }

  comment(comment: CommentRow) {
    return {
      id: comment.id,
      postId: comment.postId,
      content: comment.content,
      createdAt: comment.createdAt,
      author: this.author(comment.member),
    };
  }

  post(post: PostRow) {
    return {
      id: post.id,
      kind: post.kind,
      content: post.content,
      createdAt: post.createdAt,
      author: this.author(post.author),
      media: post.media.map((item) => this.media(item.media)),
      _count: post._count,
      likedByMe: post.likes.length > 0,
      savedByMe: post.saves.length > 0,
      comments: [...post.comments].reverse().map((comment) => this.comment(comment)),
    };
  }
}

export async function requirePost(prisma: PrismaService, academyId: string, postId: string) {
  const post = await prisma.communityPost.findFirst({
    where: { id: postId, academyId },
    select: { id: true, memberId: true },
  });
  if (!post) throw new NotFoundException('Publicação não encontrada');
  return post;
}

/** Aluno ativo com acesso ao app liberado (senha própria ou da conta vinculada). */
export function studentAppAccessWhere(): Prisma.StudentWhereInput {
  return {
    status: 'ACTIVE',
    OR: [{ passwordHash: { not: null } }, { account: { is: { passwordHash: { not: null } } } }],
  };
}

/** Perfis visíveis na comunidade: alunos ativos com acesso ao app e membros da equipe. */
export function visibleMemberWhere(academyId: string): Prisma.CommunityMemberWhereInput {
  return {
    academyId,
    OR: [{ student: { is: studentAppAccessWhere() } }, { user: { isNot: null } }],
  };
}
