import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { beltTitle, summarizeProgress, TRACK_CATEGORIES, TRACK_CATEGORY_LABELS } from '../../domain/tracks';
import { CommunityViews } from '../student-app/community-views';

export const lessonSelect = {
  id: true,
  beltId: true,
  category: true,
  title: true,
  description: true,
  position: true,
  published: true,
  updatedAt: true,
  media: { select: { id: true, kind: true } },
} satisfies Prisma.TrackLessonSelect;

export type LessonRow = Prisma.TrackLessonGetPayload<{ select: typeof lessonSelect }>;
export type BeltRow = { id: string; name: string; color: string; order: number };

export const lessonOrder: Prisma.TrackLessonOrderByWithRelationInput[] = [{ position: 'asc' }, { createdAt: 'asc' }];

@Injectable()
export class TrackViews {
  constructor(private readonly community: CommunityViews) {}

  belt(belt: BeltRow) {
    return { id: belt.id, name: belt.name, title: beltTitle(belt.name), color: belt.color, order: belt.order };
  }

  lesson(lesson: LessonRow, completed?: boolean) {
    return {
      id: lesson.id,
      beltId: lesson.beltId,
      category: lesson.category,
      title: lesson.title,
      description: lesson.description,
      position: lesson.position,
      published: lesson.published,
      updatedAt: lesson.updatedAt,
      media: lesson.media ? this.community.media(lesson.media) : null,
      ...(completed === undefined ? {} : { completed }),
    };
  }

  /** Agrupa nas quatro categorias, sempre na mesma ordem e mesmo quando vazias. */
  categories(lessons: LessonRow[], completedIds?: ReadonlySet<string>) {
    return TRACK_CATEGORIES.map((key) => {
      const items = lessons.filter((lesson) => lesson.category === key);
      return {
        key,
        label: TRACK_CATEGORY_LABELS[key],
        lessons: items.map((lesson) => this.lesson(lesson, completedIds?.has(lesson.id))),
        ...(completedIds ? { progress: summarizeProgress(items.map((l) => l.id), completedIds) } : {}),
      };
    });
  }
}
