import {
  exploreScore,
  handleFromName,
  rankForExplore,
  shouldNotify,
  storyExpiresAt,
  validatePostShape,
} from './social';

describe('storyExpiresAt', () => {
  it('expira 24 horas depois da publicação', () => {
    const created = new Date('2026-11-17T10:00:00Z');
    expect(storyExpiresAt(created).toISOString()).toBe('2026-11-18T10:00:00.000Z');
  });
});

describe('shouldNotify', () => {
  it('não notifica ações sobre o próprio conteúdo', () => {
    expect(shouldNotify('a', 'a')).toBe(false);
    expect(shouldNotify('a', 'b')).toBe(true);
  });
});

describe('explorar', () => {
  const now = new Date('2026-11-17T12:00:00Z');
  const hoursAgo = (h: number) => new Date(now.getTime() - h * 3_600_000);

  it('comentários pesam mais que curtidas', () => {
    const liked = exploreScore({ id: 'a', likes: 2, comments: 0, createdAt: hoursAgo(1) }, now);
    const commented = exploreScore({ id: 'b', likes: 0, comments: 2, createdAt: hoursAgo(1) }, now);
    expect(commented).toBeGreaterThan(liked);
  });

  it('publicações antigas perdem posição para recentes com engajamento parecido', () => {
    const ranked = rankForExplore(
      [
        { id: 'antigo', likes: 10, comments: 1, createdAt: hoursAgo(72) },
        { id: 'recente', likes: 8, comments: 1, createdAt: hoursAgo(2) },
      ],
      now,
    );
    expect(ranked).toEqual(['recente', 'antigo']);
  });
});

describe('validatePostShape', () => {
  it('exige texto ou mídia em um post', () => {
    expect(validatePostShape({ kind: 'POST', content: '', mediaKinds: [] })).toBe('Escreva algo ou adicione uma foto');
    expect(validatePostShape({ kind: 'POST', content: 'Oss', mediaKinds: [] })).toBeNull();
    expect(validatePostShape({ kind: 'POST', content: '', mediaKinds: ['IMAGE'] })).toBeNull();
  });

  it('limita o carrossel a 10 itens', () => {
    const kinds = Array.from({ length: 11 }, () => 'IMAGE' as const);
    expect(validatePostShape({ kind: 'POST', content: '', mediaKinds: kinds })).toMatch(/no máximo 10/);
  });

  it('rola aceita apenas um vídeo', () => {
    expect(validatePostShape({ kind: 'REEL', content: '', mediaKinds: ['VIDEO'] })).toBeNull();
    expect(validatePostShape({ kind: 'REEL', content: '', mediaKinds: ['IMAGE'] })).not.toBeNull();
    expect(validatePostShape({ kind: 'REEL', content: '', mediaKinds: ['VIDEO', 'VIDEO'] })).not.toBeNull();
  });
});

describe('handleFromName', () => {
  it('gera @usuario sem acentos', () => {
    expect(handleFromName('Ana Silva')).toBe('ana.silva');
    expect(handleFromName('  João  Conceição ')).toBe('joao.conceicao');
    expect(handleFromName('!!!')).toBe('aluno');
  });
});
