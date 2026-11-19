import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { storyExpiresAt } from '../../domain/social';
import { CommunityStoryDto } from './community.dto';
import { CommunityMediaService } from './community-media.service';
import { authorSelect, CommunityViews, Viewer, visibleMemberWhere } from './community-views';

type StoryView = ReturnType<CommunityStoriesService['storyView']>;
type StoryGroup = { author: ReturnType<CommunityViews['author']>; isMe: boolean; stories: StoryView[] };

/** Flashes: fotos e vídeos que ficam 24 horas no topo do feed. */
@Injectable()
export class CommunityStoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly views: CommunityViews,
    private readonly media: CommunityMediaService,
  ) {}

  /**
   * Bandeja de flashes ativos: os meus primeiro, depois de quem eu sigo,
   * com grupos ainda não vistos à frente dos já vistos.
   */
  async tray(viewer: Viewer) {
    const stories = await this.prisma.communityStory.findMany({
      where: {
        academyId: viewer.academyId,
        expiresAt: { gt: new Date() },
        author: {
          AND: [
            visibleMemberWhere(viewer.academyId),
            { OR: [{ id: viewer.memberId }, { followers: { some: { followerId: viewer.memberId } } }] },
          ],
        },
      },
      orderBy: { createdAt: 'asc' },
      include: {
        author: { select: authorSelect },
        media: { select: { id: true, kind: true } },
        views: { where: { memberId: viewer.memberId }, select: { memberId: true }, take: 1 },
      },
    });

    const groups = new Map<string, StoryGroup>();
    for (const story of stories) {
      const isMe = story.memberId === viewer.memberId;
      const group = groups.get(story.memberId) ?? { author: this.views.author(story.author), isMe, stories: [] };
      group.stories.push(this.storyView(story, story.views.length > 0 || isMe));
      groups.set(story.memberId, group);
    }
    return [...groups.values()]
      .map((group) => ({ ...group, hasUnseen: group.stories.some((story) => !story.seen) }))
      .sort((a, b) => Number(b.isMe) - Number(a.isMe) || Number(b.hasUnseen) - Number(a.hasUnseen));
  }

  async create(viewer: Viewer, dto: CommunityStoryDto) {
    const [media] = await this.media.claimable(viewer, [dto.mediaId]);
    const createdAt = new Date();
    const story = await this.prisma.communityStory.create({
      data: {
        academyId: viewer.academyId,
        memberId: viewer.memberId,
        mediaId: media.id,
        caption: dto.caption || null,
        createdAt,
        expiresAt: storyExpiresAt(createdAt),
      },
      include: { media: { select: { id: true, kind: true } } },
    });
    return this.storyView(story, true);
  }

  async markViewed(viewer: Viewer, storyId: string) {
    const story = await this.activeStory(viewer.academyId, storyId);
    if (story.memberId !== viewer.memberId) {
      await this.prisma.communityStoryView.upsert({
        where: { storyId_memberId: { storyId, memberId: viewer.memberId } },
        create: { storyId, memberId: viewer.memberId },
        update: {},
      });
    }
    return { viewed: true };
  }

  async viewers(viewer: Viewer, storyId: string) {
    const story = await this.activeStory(viewer.academyId, storyId);
    if (story.memberId !== viewer.memberId) throw new ForbiddenException('Somente o autor vê quem assistiu');
    const views = await this.prisma.communityStoryView.findMany({
      where: { storyId },
      orderBy: { viewedAt: 'desc' },
      take: 200,
      select: { viewedAt: true, member: { select: authorSelect } },
    });
    return views.map((view) => ({ ...this.views.author(view.member), viewedAt: view.viewedAt }));
  }

  async remove(viewer: Viewer, storyId: string) {
    const story = await this.prisma.communityStory.findFirst({
      where: { id: storyId, academyId: viewer.academyId },
      select: { memberId: true, mediaId: true },
    });
    if (!story) throw new NotFoundException('Flash não encontrado');
    if (story.memberId !== viewer.memberId) throw new ForbiddenException('Você só pode apagar seus flashes');
    await this.prisma.communityStory.delete({ where: { id: storyId } });
    await this.media.discard([story.mediaId]);
    return { deleted: true };
  }

  private storyView(
    story: { id: string; caption: string | null; createdAt: Date; expiresAt: Date; media: { id: string; kind: 'IMAGE' | 'VIDEO' } },
    seen: boolean,
  ) {
    return {
      id: story.id,
      caption: story.caption,
      createdAt: story.createdAt,
      expiresAt: story.expiresAt,
      media: this.views.media(story.media),
      seen,
    };
  }

  private async activeStory(academyId: string, storyId: string) {
    const story = await this.prisma.communityStory.findFirst({
      where: { id: storyId, academyId, expiresAt: { gt: new Date() } },
      select: { memberId: true },
    });
    if (!story) throw new NotFoundException('Flash não encontrado ou expirado');
    return story;
  }
}
