import { APP_TIMEZONE } from '../../domain/dates';
import { PrismaService } from '../../common/prisma.service';
import { GraduationsService } from './graduations.service';

describe('GraduationsService', () => {
  it('counts at most one check-in per local day and modality for graduation', async () => {
    const queryRaw = jest.fn().mockResolvedValue([]);
    const service = new GraduationsService({ $queryRaw: queryRaw } as unknown as PrismaService);

    await service.board('academy-1', {});

    const [strings, ...values] = queryRaw.mock.calls[0] as unknown as [
      TemplateStringsArray,
      ...unknown[],
    ];
    const sql = strings.join(' ? ');
    expect(sql).toContain('count(DISTINCT (ci."checkedAt" AT TIME ZONE ');
    expect(sql).toContain(')::date)::int FROM "CheckIn" ci');
    expect(values).toContain(APP_TIMEZONE);
  });
});
