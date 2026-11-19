import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PaginationQuery, paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { rankForExplore, validatePostShape } from '../../domain/social';
import { CommunityCommentDto, CommunityFeedQuery, CommunityPostDto } from './community.dto';
import { CommunityMediaService } from './community-media.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { authorSelect, CommunityViews, postInclude, requirePost, Viewer } from './community-views';

const EXPLORE_WINDOW_DAYS = 60;
const EXPLORE_CANDIDATES = 300;

@Injectable()
export class CommunityPostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly views: CommunityViews,
    private readonly media: CommunityMediaService,
    private readonly notifications: CommunityNotificationsService,
  ) {}

  async feed(viewer: Viewer, query: CommunityFeedQuery) {
    const where: Prisma.CommunityPostWhereInput = { academyId: viewer.academyId };
    if (query.kind) where.kind = query.kind;
    if (query.authorId) where.memberId = query.authorId;
    if (query.scope === 'following') {
      where.author = {
        OR: [{ id: viewer.memberId }, { followers: { some: { followerId: viewer.memberId } } }],
      };
    }
    return this.page(viewer, where, query);
  }

  async findOne(viewer: Viewer, postId: string) {
    const post = await this.prisma.communityPost.findFirst({
      where: { id: postId, academyId: viewer.academyId },
      include: postInclude(viewer.memberId),
    });
    if (!post) throw new NotFoundException('Publicação não encontrada');
    return this.views.post(post);
  }

  async createPost(viewer: Viewer, dto: CommunityPostDto) {
    const content = dto.content?.trim() ?? '';
    const kind = dto.kind ?? 'POST';
    const media = await this.media.claimable(viewer, dto.mediaIds ?? []);
    const problem = validatePostShape({ kind, content, mediaKinds: media.map((item) => item.kind) });
    if (problem) throw new BadRequestException(problem);

    const post = await this.prisma.communityPost.create({
      data: {
        academyId: viewer.academyId,
        memberId: viewer.memberId,
        content,
        kind,
        media: { create: media.map((item, position) => ({ mediaId: item.id, position })) },
      },
      include: postInclude(viewer.memberId),
    });
    return this.views.post(post);
  }

  async deletePost(viewer: Viewer, postId: string) {
    const post = await requirePost(this.prisma, viewer.academyId, postId);
    if (post.memberId !== viewer.memberId) throw new ForbiddenException('Você só pode apagar suas publicações');
    const media = await this.prisma.communityPostMedia.findMany({ where: { postId }, select: { mediaId: true } });
    await this.prisma.communityPost.delete({ where: { id: postId } });
    await this.media.discard(media.map((item) => item.mediaId));
    return { deleted: true };
  }

  async toggleLike(viewer: Viewer, postId: string) {
    const post = await requirePost(this.prisma, viewer.academyId, postId);
    const existing = await this.prisma.communityPostLike.findUnique({
      where: { postId_memberId: { postId, memberId: viewer.memberId } },
      select: { id: true },
    });
    const event = { actorId: viewer.memberId, recipientId: post.memberId, type: 'LIKE' as const, postId };
    if (existing) {
      await this.prisma.communityPostLike.delete({ where: { id: existing.id } });
      await this.notifications.retract(event);
      return { liked: false };
    }
    await this.prisma.communityPostLike.create({ data: { postId, memberId: viewer.memberId } });
    await this.notifications.notify({ ...event, academyId: viewer.academyId });
    return { liked: true };
  }

  async comments(viewer: Viewer, postId: string, query: PaginationQuery) {
    await requirePost(this.prisma, viewer.academyId, postId);
    const where = { postId };
    const [rows, total] = await Promise.all([
      this.prisma.communityPostComment.findMany({
        where,
        orderBy: { createdAt: 'asc' },
        ...paginationArgs(query),
        include: { member: { select: authorSelect } },
      }),
      this.prisma.communityPostComment.count({ where }),
    ]);
    return toPaginated(rows.map((row) => this.views.comment(row)), total, query);
  }

  async addComment(viewer: Viewer, postId: string, dto: CommunityCommentDto) {
    const post = await requirePost(this.prisma, viewer.academyId, postId);
    const content = dto.content.trim();
    if (!content) throw new BadRequestException('Escreva um comentário');
    const comment = await this.prisma.communityPostComment.create({
      data: { postId, memberId: viewer.memberId, content },
      include: { member: { select: authorSelect } },
    });
    await this.notifications.notify({
      academyId: viewer.academyId,
      actorId: viewer.memberId,
      recipientId: post.memberId,
      type: 'COMMENT',
      postId,
    });
    return this.views.comment(comment);
  }

  /** O autor do comentário ou o dono da publicação podem apagar. */
  async deleteComment(viewer: Viewer, postId: string, commentId: string) {
    const post = await requirePost(this.prisma, viewer.academyId, postId);
    const comment = await this.prisma.communityPostComment.findFirst({
      where: { id: commentId, postId },
      select: { id: true, memberId: true },
    });
    if (!comment) throw new NotFoundException('Comentário não encontrado');
    if (comment.memberId !== viewer.memberId && post.memberId !== viewer.memberId) {
      throw new ForbiddenException('Você não pode apagar este comentário');
    }
    await this.prisma.communityPostComment.delete({ where: { id: commentId } });
    return { deleted: true };
  }

  async toggleSave(viewer: Viewer, postId: string) {
    await requirePost(this.prisma, viewer.academyId, postId);
    const key = { postId_memberId: { postId, memberId: viewer.memberId } };
    const existing = await this.prisma.communityPostSave.findUnique({ where: key, select: { postId: true } });
    if (existing) {
      await this.prisma.communityPostSave.delete({ where: key });
      return { saved: false };
    }
    await this.prisma.communityPostSave.create({ data: { postId, memberId: viewer.memberId } });
    return { saved: true };
  }

  async saved(viewer: Viewer, query: PaginationQuery) {
    const where = { memberId: viewer.memberId, post: { academyId: viewer.academyId } };
    const [rows, total] = await Promise.all([
      this.prisma.communityPostSave.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        ...paginationArgs(query),
        include: { post: { include: postInclude(viewer.memberId) } },
      }),
      this.prisma.communityPostSave.count({ where }),
    ]);
    return toPaginated(rows.map((row) => this.views.post(row.post)), total, query);
  }

  /** Publicações com mídia dos últimos 60 dias, ordenadas por engajamento recente. */
  async explore(viewer: Viewer, query: PaginationQuery) {
    const since = new Date(Date.now() - EXPLORE_WINDOW_DAYS * 24 * 60 * 60 * 1000);
    const candidates = await this.prisma.communityPost.findMany({
      where: { academyId: viewer.academyId, createdAt: { gte: since }, media: { some: {} } },
      orderBy: { createdAt: 'desc' },
      take: EXPLORE_CANDIDATES,
      select: { id: true, createdAt: true, _count: { select: { likes: true, comments: true } } },
    });
    const ranked = rankForExplore(
      candidates.map((c) => ({ id: c.id, createdAt: c.createdAt, likes: c._count.likes, comments: c._count.comments })),
      new Date(),
    );
    const { skip, take } = paginationArgs(query);
    const pageIds = ranked.slice(skip, skip + take);
    const rows = await this.prisma.communityPost.findMany({
      where: { id: { in: pageIds } },
      include: postInclude(viewer.memberId),
    });
    const byId = new Map(rows.map((row) => [row.id, row]));
    const items = pageIds.flatMap((id) => (byId.has(id) ? [this.views.post(byId.get(id)!)] : []));
    return toPaginated(items, ranked.length, query);
  }

  private async page(viewer: Viewer, where: Prisma.CommunityPostWhereInput, query: PaginationQuery) {
    const [rows, total] = await Promise.all([
      this.prisma.communityPost.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        ...paginationArgs(query),
        include: postInclude(viewer.memberId),
      }),
      this.prisma.communityPost.count({ where }),
    ]);
    return toPaginated(rows.map((row) => this.views.post(row)), total, query);
  }
}
