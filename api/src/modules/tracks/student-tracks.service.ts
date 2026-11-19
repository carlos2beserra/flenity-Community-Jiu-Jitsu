import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthUser } from '../../common/auth';
import { PrismaService } from '../../common/prisma.service';
import { summarizeProgress } from '../../domain/tracks';
import { studentAppAccessWhere } from '../student-app/community-views';
import { BeltRow, lessonOrder, lessonSelect, TrackViews } from './track-views';

type CurrentBelt = { belt: BeltRow; modalityId: string; degree: number };

const beltSelect = { id: true, name: true, color: true, order: true, modalityId: true } as const;

/** Trilha do aluno: videoaulas liberadas pelo professor para a faixa atual e as anteriores (revisão). */
@Injectable()
export class StudentTracksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly views: TrackViews,
  ) {}

  async overview(user: AuthUser, beltId?: string) {
    const current = await this.currentBelt(user);
    const belts = await this.prisma.belt.findMany({
      where: { modalityId: current.modalityId, order: { lte: current.belt.order } },
      orderBy: { order: 'asc' },
      select: beltSelect,
    });
    const selected = beltId ? belts.find((belt) => belt.id === beltId) : current.belt;
    if (!selected) throw new NotFoundException('Essa faixa ainda não foi liberada para você');

    const published = await this.prisma.trackLesson.findMany({
      where: {
        academyId: user.academyId,
        beltId: { in: belts.map((belt) => belt.id) },
        published: true,
        mediaId: { not: null },
      },
      select: lessonSelect,
      orderBy: lessonOrder,
    });
    const done = await this.prisma.trackProgress.findMany({
      where: { studentId: user.userId, lessonId: { in: published.map((lesson) => lesson.id) } },
      select: { lessonId: true },
    });
    const completed = new Set(done.map((row) => row.lessonId));
    const idsOf = (id: string) => published.filter((lesson) => lesson.beltId === id).map((lesson) => lesson.id);

    return {
      current: { ...this.views.belt(current.belt), degree: current.degree },
      belts: belts.map((belt) => ({
        ...this.views.belt(belt),
        current: belt.id === current.belt.id,
        progress: summarizeProgress(idsOf(belt.id), completed),
      })),
      belt: this.views.belt(selected),
      progress: summarizeProgress(idsOf(selected.id), completed),
      categories: this.views.categories(
        published.filter((lesson) => lesson.beltId === selected.id),
        completed,
      ),
    };
  }

  async setCompleted(user: AuthUser, lessonId: string, completed: boolean) {
    const current = await this.currentBelt(user);
    const lesson = await this.prisma.trackLesson.findFirst({
      where: {
        id: lessonId,
        academyId: user.academyId,
        published: true,
        mediaId: { not: null },
        belt: { modalityId: current.modalityId, order: { lte: current.belt.order } },
      },
      select: { id: true },
    });
    if (!lesson) throw new NotFoundException('Conceito não encontrado');

    const key = { studentId: user.userId, lessonId };
    if (completed) {
      await this.prisma.trackProgress.upsert({ where: { studentId_lessonId: key }, create: key, update: {} });
    } else {
      await this.prisma.trackProgress.deleteMany({ where: key });
    }
    return { completed };
  }

  /** Faixa mais recente do aluno; quem ainda não foi graduado começa na primeira faixa da academia. */
  private async currentBelt(user: AuthUser): Promise<CurrentBelt> {
    const student = await this.prisma.student.findFirst({
      where: { id: user.userId, academyId: user.academyId, ...studentAppAccessWhere() },
      select: { id: true },
    });
    if (!student) throw new ForbiddenException('Seu acesso ao app não está ativo');

    const rank = await this.prisma.studentRank.findFirst({
      where: { studentId: student.id, belt: { modality: { academyId: user.academyId } } },
      orderBy: { promotedAt: 'desc' },
      select: { degree: true, belt: { select: beltSelect } },
    });
    if (rank) return { belt: rank.belt, modalityId: rank.belt.modalityId, degree: rank.degree };

    const first = await this.prisma.belt.findFirst({
      where: { modality: { academyId: user.academyId } },
      orderBy: [{ modality: { name: 'asc' } }, { order: 'asc' }],
      select: beltSelect,
    });
    if (!first) throw new NotFoundException('A academia ainda não cadastrou as faixas');
    return { belt: first, modalityId: first.modalityId, degree: 0 };
  }
}
