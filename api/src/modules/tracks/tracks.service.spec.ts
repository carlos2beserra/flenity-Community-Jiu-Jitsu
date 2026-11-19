import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { AuthUser } from '../../common/auth';
import { asPrisma, createPrismaMock, PrismaMock, testViews } from '../student-app/community.test-helpers';
import { CommunityMediaService } from '../student-app/community-media.service';
import { CommunityMembersService } from '../student-app/community-members.service';
import { StudentTracksService } from './student-tracks.service';
import { TrackViews } from './track-views';
import { TracksService } from './tracks.service';

const academyId = 'academy-1';
const staff: AuthUser = { userId: 'prof-1', academyId, role: 'INSTRUCTOR' };
const student: AuthUser = { userId: 'student-1', academyId, role: 'STUDENT' };

const belt = (id: string, order: number, name = ['Branca', 'Azul', 'Roxa'][order]) => ({
  id,
  name,
  color: '#fff',
  order,
  modalityId: 'bjj',
});

const lesson = (id: string, overrides: Record<string, unknown> = {}) => ({
  id,
  beltId: 'white',
  category: 'GUARD',
  title: `Conceito ${id}`,
  description: null,
  position: 0,
  published: true,
  updatedAt: new Date('2026-11-18T12:00:00Z'),
  media: null,
  ...overrides,
});

describe('TracksService (professor)', () => {
  let prisma: PrismaMock;
  let media: { claimable: jest.Mock; discard: jest.Mock };
  let service: TracksService;

  beforeEach(() => {
    prisma = createPrismaMock();
    media = { claimable: jest.fn(), discard: jest.fn() };
    const members = { resolve: jest.fn().mockResolvedValue({ memberId: 'member-prof', academyId }) };
    service = new TracksService(
      asPrisma(prisma),
      members as unknown as CommunityMembersService,
      media as unknown as CommunityMediaService,
      new TrackViews(testViews()),
    );
    prisma.$transaction.mockImplementation((ops: unknown[]) => Promise.all(ops));
  });

  it('mostra as faixas com contagens e os conceitos da faixa escolhida nas quatro categorias', async () => {
    prisma.belt.findMany.mockResolvedValue([belt('white', 0), belt('blue', 1)]);
    prisma.trackLesson.groupBy.mockResolvedValue([
      { beltId: 'blue', published: true, _count: { _all: 2 } },
      { beltId: 'blue', published: false, _count: { _all: 1 } },
    ]);
    (prisma as unknown as Record<string, unknown>).$queryRaw = jest.fn().mockResolvedValue([{ beltId: 'blue', students: 7 }]);
    prisma.trackLesson.findMany.mockResolvedValue([lesson('l1', { beltId: 'blue', category: 'PASS', published: false })]);

    const result = await service.overview(academyId, 'blue');

    expect(result.belt?.title).toBe('Faixa Azul');
    expect(result.belts[1]).toMatchObject({ lessonCount: 3, publishedCount: 2, studentCount: 7 });
    expect(result.belts[0]).toMatchObject({ lessonCount: 0, studentCount: 0 });
    expect(result.categories.map((c) => c.label)).toEqual(['Guarda', 'Passagem', 'Controle', 'Finalizações']);
    expect(result.categories[1].lessons).toEqual([expect.objectContaining({ id: 'l1', published: false })]);
    expect(prisma.trackLesson.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { academyId, beltId: 'blue' } }));
  });

  it('recusa faixa de outra academia', async () => {
    prisma.belt.findMany.mockResolvedValue([belt('white', 0)]);
    await expect(service.overview(academyId, 'outra')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('cria conceito como rascunho no fim da categoria, com vídeo do próprio professor', async () => {
    prisma.belt.findFirst.mockResolvedValue(belt('white', 0));
    prisma.trackLesson.aggregate.mockResolvedValue({ _max: { position: 2 } });
    media.claimable.mockResolvedValue([{ id: 'video-1', kind: 'VIDEO' }]);
    prisma.trackLesson.create.mockResolvedValue(lesson('new', { published: false, position: 3, media: { id: 'video-1', kind: 'VIDEO' } }));

    const created = await service.create(staff, { beltId: 'white', category: 'GUARD', title: 'Guarda fechada', mediaId: 'video-1' });

    expect(media.claimable).toHaveBeenCalledWith({ memberId: 'member-prof', academyId }, ['video-1']);
    expect(prisma.trackLesson.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ academyId, position: 3, published: false, mediaId: 'video-1', description: null }),
      }),
    );
    expect(created.media?.url).toMatch(/^\/media\/video-1\?exp=\d+&sig=/);
  });

  it('recusa foto: o conteúdo da trilha é vídeo', async () => {
    prisma.belt.findFirst.mockResolvedValue(belt('white', 0));
    media.claimable.mockResolvedValue([{ id: 'foto-1', kind: 'IMAGE' }]);

    await expect(
      service.create(staff, { beltId: 'white', category: 'GUARD', title: 'Guarda', mediaId: 'foto-1' }),
    ).rejects.toThrow('O conteúdo da trilha precisa ser um vídeo');
    expect(prisma.trackLesson.create).not.toHaveBeenCalled();
  });

  it('não cria conceito em faixa de outra academia', async () => {
    prisma.belt.findFirst.mockResolvedValue(null);
    await expect(service.create(staff, { beltId: 'x', category: 'GUARD', title: 'Teste' })).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.trackLesson.create).not.toHaveBeenCalled();
  });

  it('ao trocar o vídeo apaga o antigo, e ao mudar de categoria vai para o fim da nova', async () => {
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'l1', beltId: 'white', category: 'GUARD', mediaId: 'old', published: true });
    media.claimable.mockResolvedValue([{ id: 'novo', kind: 'VIDEO' }]);
    prisma.trackLesson.aggregate.mockResolvedValue({ _max: { position: null } });
    prisma.trackLesson.update.mockResolvedValue(lesson('l1'));

    await service.update(staff, 'l1', { mediaId: 'novo', category: 'CONTROL' });

    expect(prisma.trackLesson.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ mediaId: 'novo', category: 'CONTROL', position: 0 }) }),
    );
    expect(media.discard).toHaveBeenCalledWith(['old']);
  });

  it('remover o vídeo (null) de um rascunho apaga o arquivo sem reivindicar outro', async () => {
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'l1', beltId: 'white', category: 'GUARD', mediaId: 'old', published: false });
    prisma.trackLesson.update.mockResolvedValue(lesson('l1'));

    await service.update(staff, 'l1', { mediaId: null });

    expect(media.claimable).not.toHaveBeenCalled();
    expect(prisma.trackLesson.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ mediaId: null }) }));
    expect(media.discard).toHaveBeenCalledWith(['old']);
  });

  it('só libera para o aluno conceito com vídeo', async () => {
    prisma.belt.findFirst.mockResolvedValue(belt('white', 0));
    await expect(
      service.create(staff, { beltId: 'white', category: 'GUARD', title: 'Sem vídeo', published: true }),
    ).rejects.toThrow('Envie o vídeo da aula antes de liberar');

    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'l1', beltId: 'white', category: 'GUARD', mediaId: null, published: false });
    await expect(service.update(staff, 'l1', { published: true })).rejects.toThrow('Envie o vídeo');

    // Conceito liberado não pode perder o vídeo sem antes voltar para rascunho.
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'l1', beltId: 'white', category: 'GUARD', mediaId: 'v1', published: true });
    await expect(service.update(staff, 'l1', { mediaId: null })).rejects.toThrow('Envie o vídeo');
    expect(prisma.trackLesson.update).not.toHaveBeenCalled();
    expect(media.discard).not.toHaveBeenCalled();

    // Enviar o vídeo e liberar no mesmo passo funciona.
    media.claimable.mockResolvedValue([{ id: 'v2', kind: 'VIDEO' }]);
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'l1', beltId: 'white', category: 'GUARD', mediaId: null, published: false });
    prisma.trackLesson.update.mockResolvedValue(lesson('l1'));
    await service.update(staff, 'l1', { mediaId: 'v2', published: true });
    expect(prisma.trackLesson.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ mediaId: 'v2', published: true }) }),
    );
  });

  it('apagar conceito apaga a mídia junto', async () => {
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'l1', beltId: 'white', category: 'GUARD', mediaId: 'm1' });
    await service.remove(academyId, 'l1');
    expect(prisma.trackLesson.delete).toHaveBeenCalledWith({ where: { id: 'l1' } });
    expect(media.discard).toHaveBeenCalledWith(['m1']);
  });

  it('não altera conceito de outra academia', async () => {
    prisma.trackLesson.findFirst.mockResolvedValue(null);
    await expect(service.update(staff, 'l1', { title: 'x' })).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.remove(academyId, 'l1')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('reordena trocando com o vizinho', async () => {
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'b', beltId: 'white', category: 'GUARD', mediaId: null });
    prisma.trackLesson.findMany.mockResolvedValue([{ id: 'a', position: 0 }, { id: 'b', position: 1 }]);

    expect(await service.move(academyId, 'b', { direction: 'up' })).toEqual({ moved: true });
    expect(prisma.trackLesson.update).toHaveBeenCalledWith({ where: { id: 'b' }, data: { position: 0 } });
    expect(prisma.trackLesson.update).toHaveBeenCalledWith({ where: { id: 'a' }, data: { position: 1 } });
  });

  it('libera em lote só os conceitos com vídeo e informa quantos ficaram sem', async () => {
    prisma.belt.findFirst.mockResolvedValue(belt('white', 0));
    prisma.trackLesson.updateMany.mockResolvedValue({ count: 3 });
    prisma.trackLesson.count.mockResolvedValue(2);

    expect(await service.publish(academyId, { beltId: 'white', category: 'SUBMISSION', published: true })).toEqual({
      updated: 3,
      withoutVideo: 2,
    });
    expect(prisma.trackLesson.updateMany).toHaveBeenCalledWith({
      where: { academyId, beltId: 'white', category: 'SUBMISSION', mediaId: { not: null } },
      data: { published: true },
    });
  });

  it('recolher em lote vale para todos', async () => {
    prisma.belt.findFirst.mockResolvedValue(belt('white', 0));
    prisma.trackLesson.updateMany.mockResolvedValue({ count: 5 });

    expect(await service.publish(academyId, { beltId: 'white', published: false })).toEqual({ updated: 5, withoutVideo: 0 });
    expect(prisma.trackLesson.updateMany).toHaveBeenCalledWith({ where: { academyId, beltId: 'white' }, data: { published: false } });
  });

  it('importa a trilha sugerida como rascunho, só em faixa vazia', async () => {
    prisma.belt.findFirst.mockResolvedValue(belt('blue', 1));
    prisma.trackLesson.count.mockResolvedValue(0);
    prisma.trackLesson.createMany.mockImplementation(({ data }: { data: unknown[] }) => ({ count: data.length }));

    const result = await service.importStarter(academyId, { beltId: 'blue' });

    const data = prisma.trackLesson.createMany.mock.calls[0][0].data as { title: string; published?: boolean; category: string }[];
    expect(result.created).toBe(data.length);
    expect(data.some((item) => item.title === 'Triângulo')).toBe(true);
    expect(new Set(data.map((item) => item.category))).toEqual(new Set(['GUARD', 'PASS', 'CONTROL', 'SUBMISSION']));
    expect(data.every((item) => item.published === undefined)).toBe(true);

    prisma.trackLesson.count.mockResolvedValue(4);
    await expect(service.importStarter(academyId, { beltId: 'blue' })).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('StudentTracksService (aluno)', () => {
  let prisma: PrismaMock;
  let service: StudentTracksService;

  beforeEach(() => {
    prisma = createPrismaMock();
    service = new StudentTracksService(asPrisma(prisma), new TrackViews(testViews()));
    prisma.student.findFirst.mockResolvedValue({ id: 'student-1' });
  });

  it('mostra a faixa atual com o que foi liberado e o progresso do aluno', async () => {
    prisma.studentRank.findFirst.mockResolvedValue({ degree: 2, belt: belt('blue', 1) });
    prisma.belt.findMany.mockResolvedValue([belt('white', 0), belt('blue', 1)]);
    prisma.trackLesson.findMany.mockResolvedValue([
      lesson('w1', { beltId: 'white' }),
      lesson('b1', { beltId: 'blue', category: 'GUARD' }),
      lesson('b2', { beltId: 'blue', category: 'SUBMISSION' }),
    ]);
    prisma.trackProgress.findMany.mockResolvedValue([{ lessonId: 'b1' }, { lessonId: 'w1' }]);

    const result = await service.overview(student);

    expect(result.current).toMatchObject({ title: 'Faixa Azul', degree: 2 });
    expect(result.belt.id).toBe('blue');
    expect(result.progress).toEqual({ completed: 1, total: 2, percent: 50 });
    expect(result.belts).toEqual([
      expect.objectContaining({ id: 'white', current: false, progress: { completed: 1, total: 1, percent: 100 } }),
      expect.objectContaining({ id: 'blue', current: true }),
    ]);
    expect(result.categories[0].lessons).toEqual([expect.objectContaining({ id: 'b1', completed: true })]);
    expect(result.categories[3].lessons).toEqual([expect.objectContaining({ id: 'b2', completed: false })]);
    // Só faixas até a atual e só conceitos liberados.
    expect(prisma.belt.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { modalityId: 'bjj', order: { lte: 1 } } }));
    expect(prisma.trackLesson.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { academyId, beltId: { in: ['white', 'blue'] }, published: true, mediaId: { not: null } },
      }),
    );
  });

  it('aluno sem graduação começa na primeira faixa', async () => {
    prisma.studentRank.findFirst.mockResolvedValue(null);
    prisma.belt.findFirst.mockResolvedValue(belt('white', 0));
    prisma.belt.findMany.mockResolvedValue([belt('white', 0)]);
    prisma.trackLesson.findMany.mockResolvedValue([]);
    prisma.trackProgress.findMany.mockResolvedValue([]);

    const result = await service.overview(student);

    expect(result.current).toMatchObject({ title: 'Faixa Branca', degree: 0 });
    expect(result.categories.every((c) => c.lessons.length === 0)).toBe(true);
  });

  it('não abre faixa acima da atual', async () => {
    prisma.studentRank.findFirst.mockResolvedValue({ degree: 0, belt: belt('white', 0) });
    prisma.belt.findMany.mockResolvedValue([belt('white', 0)]);
    await expect(service.overview(student, 'purple')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('aluno sem acesso ao app é recusado', async () => {
    prisma.student.findFirst.mockResolvedValue(null);
    await expect(service.overview(student)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('marca e desmarca conceito liberado como aprendido', async () => {
    prisma.studentRank.findFirst.mockResolvedValue({ degree: 0, belt: belt('white', 0) });
    prisma.trackLesson.findFirst.mockResolvedValue({ id: 'w1' });

    expect(await service.setCompleted(student, 'w1', true)).toEqual({ completed: true });
    expect(prisma.trackProgress.upsert).toHaveBeenCalledWith(
      expect.objectContaining({ create: { studentId: 'student-1', lessonId: 'w1' } }),
    );
    expect(prisma.trackLesson.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: 'w1',
          academyId,
          published: true,
          mediaId: { not: null },
          belt: { modalityId: 'bjj', order: { lte: 0 } },
        },
      }),
    );

    expect(await service.setCompleted(student, 'w1', false)).toEqual({ completed: false });
    expect(prisma.trackProgress.deleteMany).toHaveBeenCalledWith({ where: { studentId: 'student-1', lessonId: 'w1' } });
  });

  it('não marca conceito não liberado ou de faixa acima', async () => {
    prisma.studentRank.findFirst.mockResolvedValue({ degree: 0, belt: belt('white', 0) });
    prisma.trackLesson.findFirst.mockResolvedValue(null);
    await expect(service.setCompleted(student, 'b1', true)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.trackProgress.upsert).not.toHaveBeenCalled();
  });
});
