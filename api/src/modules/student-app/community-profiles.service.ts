import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PaginationQuery, paginationArgs, toPaginated } from '../../common/pagination';
import { PrismaService } from '../../common/prisma.service';
import { CommunityProfileDto } from './community.dto';
import { CommunityMediaService } from './community-media.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { AuthorRow, authorSelect, CommunityViews, Viewer, visibleMemberWhere } from './community-views';

const profileSelect = {
  ...authorSelect,
  bio: true,
  academy: { select: { name: true } },
  student: {
    select: {
      name: true,
      ranks: {
        orderBy: { promotedAt: 'desc' },
        take: 1,
        select: { degree: true, belt: { select: { name: true, color: true } } },
      },
    },
  },
  _count: { select: { posts: true, followers: true, following: true } },
} satisfies Prisma.CommunityMemberSelect;

@Injectable()
export class CommunityProfilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly views: CommunityViews,
    private readonly media: CommunityMediaService,
    private readonly notifications: CommunityNotificationsService,
  ) {}

  async profile(viewer: Viewer, targetId: string) {
    const member = await this.prisma.communityMember.findFirst({
      where: { ...visibleMemberWhere(viewer.academyId), id: targetId },
      select: profileSelect,
    });
    if (!member) throw new NotFoundException('Perfil não encontrado');

    const [following, followsMe] = await Promise.all([
      this.isFollowing(viewer.memberId, targetId),
      this.isFollowing(targetId, viewer.memberId),
    ]);
    const rank = member.student?.ranks[0];
    return {
      ...this.views.author(member),
      bio: member.bio ?? '',
      academyName: member.academy.name,
      belt: rank ? { name: rank.belt.name, color: rank.belt.color, degree: rank.degree } : null,
      counts: {
        posts: member._count.posts,
        followers: member._count.followers,
        following: member._count.following,
      },
      isMe: viewer.memberId === targetId,
      isFollowing: following,
      followsMe,
    };
  }

  /** Busca por nome entre alunos e equipe. A equipe aparece primeiro quando não há busca. */
  async search(viewer: Viewer, query: PaginationQuery) {
    const term = query.search?.trim();
    const nameMatch = term ? { contains: term, mode: 'insensitive' as const } : undefined;
    const where: Prisma.CommunityMemberWhereInput = {
      AND: [
        visibleMemberWhere(viewer.academyId),
        { id: { not: viewer.memberId } },
        ...(nameMatch ? [{ OR: [{ student: { is: { name: nameMatch } } }, { user: { is: { name: nameMatch } } }] }] : []),
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.communityMember.findMany({
        where,
        orderBy: [{ userId: { sort: 'asc', nulls: 'last' } }, { student: { name: 'asc' } }],
        ...paginationArgs(query),
        select: authorSelect,
      }),
      this.prisma.communityMember.count({ where }),
    ]);
    return toPaginated(await this.withFollowState(viewer, rows), total, query);
  }

  async followers(viewer: Viewer, targetId: string, query: PaginationQuery) {
    const where = { followingId: targetId, follower: { academyId: viewer.academyId } };
    const [rows, total] = await Promise.all([
      this.prisma.communityFollow.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        ...paginationArgs(query),
        select: { follower: { select: authorSelect } },
      }),
      this.prisma.communityFollow.count({ where }),
    ]);
    return toPaginated(await this.withFollowState(viewer, rows.map((row) => row.follower)), total, query);
  }

  async following(viewer: Viewer, targetId: string, query: PaginationQuery) {
    const where = { followerId: targetId, following: { academyId: viewer.academyId } };
    const [rows, total] = await Promise.all([
      this.prisma.communityFollow.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        ...paginationArgs(query),
        select: { following: { select: authorSelect } },
      }),
      this.prisma.communityFollow.count({ where }),
    ]);
    return toPaginated(await this.withFollowState(viewer, rows.map((row) => row.following)), total, query);
  }

  async toggleFollow(viewer: Viewer, targetId: string) {
    if (viewer.memberId === targetId) throw new BadRequestException('Você não pode seguir a si mesmo');
    const target = await this.prisma.communityMember.findFirst({
      where: { ...visibleMemberWhere(viewer.academyId), id: targetId },
      select: { id: true },
    });
    if (!target) throw new NotFoundException('Perfil não encontrado');

    const key = { followerId_followingId: { followerId: viewer.memberId, followingId: targetId } };
    const event = { actorId: viewer.memberId, recipientId: targetId, type: 'FOLLOW' as const };
    const existing = await this.prisma.communityFollow.findUnique({ where: key, select: { followerId: true } });
    if (existing) {
      await this.prisma.communityFollow.delete({ where: key });
      await this.notifications.retract(event);
      return { following: false };
    }
    await this.prisma.communityFollow.create({ data: { followerId: viewer.memberId, followingId: targetId } });
    await this.notifications.notify({ ...event, academyId: viewer.academyId });
    return { following: true };
  }

  async updateProfile(viewer: Viewer, dto: CommunityProfileDto) {
    const data: Prisma.CommunityMemberUpdateInput = {};
    if (dto.bio !== undefined) data.bio = dto.bio || null;

    const current = await this.prisma.communityMember.findUniqueOrThrow({
      where: { id: viewer.memberId },
      select: { avatarMediaId: true },
    });
    if (dto.avatarMediaId !== undefined && dto.avatarMediaId !== current.avatarMediaId) {
      if (dto.avatarMediaId) {
        const [media] = await this.media.claimable(viewer, [dto.avatarMediaId]);
        if (media.kind !== 'IMAGE') throw new BadRequestException('A foto de perfil precisa ser uma imagem');
        data.avatarMedia = { connect: { id: media.id } };
      } else {
        data.avatarMedia = { disconnect: true };
      }
    }

    await this.prisma.communityMember.update({ where: { id: viewer.memberId }, data });
    if (data.avatarMedia && current.avatarMediaId) await this.media.discard([current.avatarMediaId]);
    return this.profile(viewer, viewer.memberId);
  }

  private async isFollowing(followerId: string, followingId: string) {
    if (followerId === followingId) return false;
    const follow = await this.prisma.communityFollow.findUnique({
      where: { followerId_followingId: { followerId, followingId } },
      select: { followerId: true },
    });
    return follow !== null;
  }

  private async withFollowState(viewer: Viewer, people: AuthorRow[]) {
    const ids = people.map((person) => person.id);
    const follows = ids.length
      ? await this.prisma.communityFollow.findMany({
          where: { followerId: viewer.memberId, followingId: { in: ids } },
          select: { followingId: true },
        })
      : [];
    const followed = new Set(follows.map((follow) => follow.followingId));
    return people.map((person) => ({
      ...this.views.author(person),
      isMe: person.id === viewer.memberId,
      isFollowing: followed.has(person.id),
    }));
  }
}
