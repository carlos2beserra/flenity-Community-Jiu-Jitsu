import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { isEligibleForPromotion, nextRank } from '../../domain/graduation';
import { APP_TIMEZONE } from '../../domain/dates';
import { PrismaService } from '../../common/prisma.service';
import { GraduationBoardQuery, PromoteDto } from './graduations.dto';

type BoardRow = {
  studentId: string;
  studentName: string;
  modalityId: string;
  modalityName: string;
  beltId: string;
  beltName: string;
  beltColor: string;
  degree: number;
  maxDegrees: number;
  minClasses: number;
  promotedAt: Date;
  classesSince: number;
};

@Injectable()
export class GraduationsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Graduação atual de cada aluno ativo, com aulas desde a última promoção e se está apto. */
  async board(academyId: string, query: GraduationBoardQuery & { studentId?: string }) {
    const modalityFilter = query.modalityId ? Prisma.sql`AND r."modalityId" = ${query.modalityId}` : Prisma.empty;
    const studentFilter = query.studentId ? Prisma.sql`AND r."studentId" = ${query.studentId}` : Prisma.empty;
    const rows = await this.prisma.$queryRaw<BoardRow[]>`
      WITH current_rank AS (
        SELECT DISTINCT ON (r."studentId", r."modalityId") r.*
        FROM "StudentRank" r
        JOIN "Student" s ON s.id = r."studentId"
        WHERE s."academyId" = ${academyId} AND s.status = 'ACTIVE' ${modalityFilter} ${studentFilter}
        ORDER BY r."studentId", r."modalityId", r."promotedAt" DESC
      )
      SELECT c."studentId", s.name AS "studentName", c."modalityId", m.name AS "modalityName",
             c."beltId", b.name AS "beltName", b.color AS "beltColor", c.degree, b."maxDegrees", b."minClasses",
             c."promotedAt",
             (SELECT count(DISTINCT (ci."checkedAt" AT TIME ZONE ${APP_TIMEZONE})::date)::int FROM "CheckIn" ci
               WHERE ci."studentId" = c."studentId" AND ci."modalityId" = c."modalityId"
                 AND ci."checkedAt" >= c."promotedAt") AS "classesSince"
      FROM current_rank c
      JOIN "Student" s ON s.id = c."studentId"
      JOIN "Modality" m ON m.id = c."modalityId"
      JOIN "Belt" b ON b.id = c."beltId"
      ORDER BY m.name, b."order" DESC, c.degree DESC, s.name`;

    const board = rows.map((row) => ({ ...row, eligible: isEligibleForPromotion(row.classesSince, row) }));
    return query.eligibleOnly ? board.filter((row) => row.eligible) : board;
  }

  async promote(academyId: string, dto: PromoteDto) {
    await this.prisma.student.findFirstOrThrow({ where: { id: dto.studentId, academyId } });
    const modality = await this.prisma.modality.findFirstOrThrow({
      where: { id: dto.modalityId, academyId },
      include: { belts: true },
    });
    if (modality.belts.length === 0) throw new BadRequestException('Modalidade sem faixas cadastradas');

    const target = dto.beltId ? this.explicitTarget(modality.belts, dto.beltId, dto.degree ?? 0) : await this.nextTarget(dto, modality.belts);

    return this.prisma.studentRank.create({
      data: { studentId: dto.studentId, modalityId: dto.modalityId, beltId: target.beltId, degree: target.degree },
      include: { belt: true, modality: { select: { id: true, name: true } } },
    });
  }

  private explicitTarget(belts: { id: string; maxDegrees: number }[], beltId: string, degree: number) {
    const belt = belts.find((b) => b.id === beltId);
    if (!belt) throw new BadRequestException('Faixa não pertence à modalidade');
    if (degree > belt.maxDegrees) throw new BadRequestException(`Faixa permite no máximo ${belt.maxDegrees} graus`);
    return { beltId, degree };
  }

  private async nextTarget(dto: PromoteDto, belts: { id: string; order: number; maxDegrees: number; minClasses: number }[]) {
    const current = await this.prisma.studentRank.findFirst({
      where: { studentId: dto.studentId, modalityId: dto.modalityId },
      orderBy: { promotedAt: 'desc' },
    });
    if (!current) {
      const first = [...belts].sort((a, b) => a.order - b.order)[0];
      return { beltId: first.id, degree: 0 };
    }
    const next = nextRank(current, belts);
    if (!next) throw new BadRequestException('Aluno já está na graduação máxima');
    return next;
  }
}
