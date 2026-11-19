import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../../common/auth';
import { PrismaService } from '../../common/prisma.service';
import { starterFor, swapPositions, TRACK_CATEGORIES } from '../../domain/tracks';
import { CommunityMediaService } from '../student-app/community-media.service';
import { CommunityMembersService } from '../student-app/community-members.service';
import { BeltRow, lessonOrder, lessonSelect, TrackViews } from './track-views';
import { CreateTrackLessonDto, MoveTrackLessonDto, PublishTrackDto, StarterTrackDto, UpdateTrackLessonDto } from './tracks.dto';

const beltSelect = { id: true, name: true, color: true, order: true } satisfies Prisma.BeltSelect;
const NEEDS_VIDEO = 'Envie o vídeo da aula antes de liberar para os alunos';

/** Gestão das trilhas pela equipe: cadastra conceitos por faixa e libera o que o aluno pode ver. */
@Injectable()
export class TracksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly members: CommunityMembersService,
    private readonly media: CommunityMediaService,
    private readonly views: TrackViews,
  ) {}

  async overview(academyId: string, beltId?: string) {
    const belts = await this.prisma.belt.findMany({
      where: { modality: { academyId } },
      orderBy: [{ modality: { name: 'asc' } }, { order: 'asc' }],
      select: beltSelect,
    });
    const selected = beltId ? belts.find((belt) => belt.id === beltId) : belts[0];
    if (beltId && !selected) throw new NotFoundException('Faixa não encontrada');

    const [counts, students, lessons] = await Promise.all([
      this.prisma.trackLesson.groupBy({ by: ['beltId', 'published'], where: { academyId }, _count: { _all: true } }),
      this.studentsPerBelt(academyId),
      selected
        ? this.prisma.trackLesson.findMany({
            where: { academyId, beltId: selected.id },
            select: lessonSelect,
            orderBy: lessonOrder,
          })
        : Promise.resolve([]),
    ]);

    const count = (id: string, published?: boolean) =>
      counts
        .filter((row) => row.beltId === id && (published === undefined || row.published === published))
        .reduce((sum, row) => sum + row._count._all, 0);

    return {
      belts: belts.map((belt) => ({
        ...this.views.belt(belt),
        lessonCount: count(belt.id),
        publishedCount: count(belt.id, true),
        studentCount: students.get(belt.id) ?? 0,
      })),
      belt: selected ? this.views.belt(selected) : null,
      categories: this.views.categories(lessons),
    };
  }

  async create(user: AuthUser, dto: CreateTrackLessonDto) {
    await this.requireBelt(user.academyId, dto.beltId);
    if (dto.published && !dto.mediaId) throw new BadRequestException(NEEDS_VIDEO);
    const mediaId = dto.mediaId ? await this.claimMedia(user, dto.mediaId) : null;
    const position = await this.nextPosition(user.academyId, dto.beltId, dto.category);
    const lesson = await this.prisma.trackLesson.create({
      data: {
        academyId: user.academyId,
        beltId: dto.beltId,
        category: dto.category,
        title: dto.title,
        description: dto.description || null,
        mediaId,
        position,
        published: dto.published ?? false,
      },
      select: lessonSelect,
    });
    return this.views.lesson(lesson);
  }

  async update(user: AuthUser, lessonId: string, dto: UpdateTrackLessonDto) {
    const current = await this.requireLesson(user.academyId, lessonId);
    const mediaChanged = dto.mediaId !== undefined && dto.mediaId !== current.mediaId;
    const willHaveVideo = mediaChanged ? Boolean(dto.mediaId) : current.mediaId !== null;
    if ((dto.published ?? current.published) && !willHaveVideo) throw new BadRequestException(NEEDS_VIDEO);
    const mediaId = mediaChanged && dto.mediaId ? await this.claimMedia(user, dto.mediaId) : undefined;
    const categoryChanged = dto.category !== undefined && dto.category !== current.category;

    const lesson = await this.prisma.trackLesson.update({
      where: { id: lessonId },
      data: {
        title: dto.title,
        description: dto.description === undefined ? undefined : dto.description || null,
        published: dto.published,
        ...(mediaChanged ? { mediaId: mediaId ?? null } : {}),
        ...(categoryChanged
          ? { category: dto.category, position: await this.nextPosition(user.academyId, current.beltId, dto.category!) }
          : {}),
      },
      select: lessonSelect,
    });
    if (mediaChanged && current.mediaId) await this.media.discard([current.mediaId]);
    return this.views.lesson(lesson);
  }

  async remove(academyId: string, lessonId: string) {
    const lesson = await this.requireLesson(academyId, lessonId);
    await this.prisma.trackLesson.delete({ where: { id: lessonId } });
    if (lesson.mediaId) await this.media.discard([lesson.mediaId]);
    return { deleted: true };
  }

  async move(academyId: string, lessonId: string, dto: MoveTrackLessonDto) {
    const lesson = await this.requireLesson(academyId, lessonId);
    const siblings = await this.prisma.trackLesson.findMany({
      where: { academyId, beltId: lesson.beltId, category: lesson.category },
      select: { id: true, position: true },
      orderBy: lessonOrder,
    });
    const changes = swapPositions(siblings, lessonId, dto.direction);
    if (changes.length > 0) {
      await this.prisma.$transaction(
        changes.map(([id, position]) => this.prisma.trackLesson.update({ where: { id }, data: { position } })),
      );
    }
    return { moved: changes.length > 0 };
  }

  /**
   * Libera (ou recolhe) todos os conceitos de uma faixa, ou só de uma categoria.
   * Ao liberar, conceitos ainda sem vídeo ficam em rascunho e são informados em `withoutVideo`.
   */
  async publish(academyId: string, dto: PublishTrackDto) {
    await this.requireBelt(academyId, dto.beltId);
    const scope = { academyId, beltId: dto.beltId, ...(dto.category ? { category: dto.category } : {}) };
    const { count } = await this.prisma.trackLesson.updateMany({
      where: dto.published ? { ...scope, mediaId: { not: null } } : scope,
      data: { published: dto.published },
    });
    const withoutVideo = dto.published ? await this.prisma.trackLesson.count({ where: { ...scope, mediaId: null } }) : 0;
    return { updated: count, withoutVideo };
  }

  /** Importa a trilha sugerida como rascunho: o professor grava os vídeos e libera depois. */
  async importStarter(academyId: string, dto: StarterTrackDto) {
    const belt = await this.requireBelt(academyId, dto.beltId);
    const existing = await this.prisma.trackLesson.count({ where: { academyId, beltId: belt.id } });
    if (existing > 0) throw new ConflictException('Essa faixa já tem conteúdo. Apague os conceitos para importar a sugestão.');

    const starter = starterFor(belt.order);
    const data = TRACK_CATEGORIES.flatMap((category) =>
      starter[category].map((lesson, position) => ({
        academyId,
        beltId: belt.id,
        category,
        title: lesson.title,
        description: lesson.description,
        position,
      })),
    );
    const { count } = await this.prisma.trackLesson.createMany({ data });
    return { created: count };
  }

  private async requireBelt(academyId: string, beltId: string): Promise<BeltRow> {
    const belt = await this.prisma.belt.findFirst({ where: { id: beltId, modality: { academyId } }, select: beltSelect });
    if (!belt) throw new NotFoundException('Faixa não encontrada');
    return belt;
  }

  private async requireLesson(academyId: string, lessonId: string) {
    const lesson = await this.prisma.trackLesson.findFirst({
      where: { id: lessonId, academyId },
      select: { id: true, beltId: true, category: true, mediaId: true, published: true },
    });
    if (!lesson) throw new NotFoundException('Conceito não encontrado');
    return lesson;
  }

  /** As trilhas são videoaulas: só aceita vídeo enviado pelo próprio professor e ainda não usado. */
  private async claimMedia(user: AuthUser, mediaId: string) {
    const [media] = await this.media.claimable(await this.members.resolve(user), [mediaId]);
    if (media.kind !== 'VIDEO') throw new BadRequestException('O conteúdo da trilha precisa ser um vídeo');
    return media.id;
  }

  private async nextPosition(academyId: string, beltId: string, category: CreateTrackLessonDto['category']) {
    const { _max } = await this.prisma.trackLesson.aggregate({
      where: { academyId, beltId, category },
      _max: { position: true },
    });
    return (_max.position ?? -1) + 1;
  }

  /** Alunos ativos por faixa atual (graduação mais recente de cada modalidade). */
  private async studentsPerBelt(academyId: string) {
    const rows = await this.prisma.$queryRaw<{ beltId: string; students: number }[]>`
      SELECT c."beltId", count(*)::int AS students
      FROM (
        SELECT DISTINCT ON (r."studentId", r."modalityId") r."beltId"
        FROM "StudentRank" r
        JOIN "Student" s ON s.id = r."studentId"
        WHERE s."academyId" = ${academyId} AND s.status = 'ACTIVE'
        ORDER BY r."studentId", r."modalityId", r."promotedAt" DESC
      ) c
      GROUP BY c."beltId"`;
    return new Map(rows.map((row) => [row.beltId, row.students]));
  }
}
