import { Injectable } from '@nestjs/common';
import { CommunityNotificationType } from '@prisma/client';
import { PaginationQuery, paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { shouldNotify } from '../../domain/social';
import { authorSelect, CommunityViews, Viewer } from './community-views';

export type NotificationEvent = {
  academyId: string;
  actorId: string;
  recipientId: string;
  type: CommunityNotificationType;
  postId?: string;
};

@Injectable()
export class CommunityNotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly views: CommunityViews,
  ) {}

  async notify(event: NotificationEvent): Promise<void> {
    if (!shouldNotify(event.actorId, event.recipientId)) return;
    await this.prisma.communityNotification.create({
      data: {
        academyId: event.academyId,
        actorId: event.actorId,
        recipientId: event.recipientId,
        type: event.type,
        postId: event.postId ?? null,
      },
    });
  }

  /** Desfazer curtida/seguir remove a notificação correspondente. Comentários não são retirados. */
  async retract(event: Omit<NotificationEvent, 'academyId'>): Promise<void> {
    await this.prisma.communityNotification.deleteMany({
      where: {
        actorId: event.actorId,
        recipientId: event.recipientId,
        type: event.type,
        postId: event.postId ?? null,
      },
    });
  }

  async list(viewer: Viewer, query: PaginationQuery) {
    const where = { recipientId: viewer.memberId, academyId: viewer.academyId };
    const [rows, total] = await Promise.all([
      this.prisma.communityNotification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        ...paginationArgs(query),
        include: {
          actor: { select: authorSelect },
          post: {
            select: {
              id: true,
              kind: true,
              media: {
                orderBy: { position: 'asc' },
                take: 1,
                select: { media: { select: { id: true, kind: true } } },
              },
            },
          },
        },
      }),
      this.prisma.communityNotification.count({ where }),
    ]);
    const followingIds = await this.followingAmong(
      viewer.memberId,
      rows.filter((row) => row.type === 'FOLLOW').map((row) => row.actorId),
    );
    const items = rows.map((row) => ({
      id: row.id,
      type: row.type,
      createdAt: row.createdAt,
      read: row.readAt !== null,
      actor: this.views.author(row.actor),
      followingActor: followingIds.has(row.actorId),
      post: row.post
        ? {
            id: row.post.id,
            kind: row.post.kind,
            thumbnail: row.post.media[0] ? this.views.media(row.post.media[0].media) : null,
          }
        : null,
    }));
    return toPaginated(items, total, query);
  }

  async unreadCount(viewer: Viewer) {
    const count = await this.prisma.communityNotification.count({
      where: { recipientId: viewer.memberId, academyId: viewer.academyId, readAt: null },
    });
    return { count };
  }

  async markAllRead(viewer: Viewer) {
    const result = await this.prisma.communityNotification.updateMany({
      where: { recipientId: viewer.memberId, academyId: viewer.academyId, readAt: null },
      data: { readAt: new Date() },
    });
    return { updated: result.count };
  }

  private async followingAmong(memberId: string, ids: string[]): Promise<Set<string>> {
    if (ids.length === 0) return new Set();
    const follows = await this.prisma.communityFollow.findMany({
      where: { followerId: memberId, followingId: { in: ids } },
      select: { followingId: true },
    });
    return new Set(follows.map((follow) => follow.followingId));
  }
}
