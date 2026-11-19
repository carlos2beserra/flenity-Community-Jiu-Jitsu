import { beltTitle, canStudentSeeBelt, STARTER_CURRICULUM, starterFor, summarizeProgress, swapPositions, TRACK_CATEGORIES } from './tracks';

describe('trilhas por faixa', () => {
  it('monta o título da faixa sem repetir "Faixa"', () => {
    expect(beltTitle('Branca')).toBe('Faixa Branca');
    expect(beltTitle(' Azul ')).toBe('Faixa Azul');
    expect(beltTitle('Faixa Preta')).toBe('Faixa Preta');
  });

  it('aluno vê a faixa atual e as anteriores, nunca as próximas', () => {
    expect(canStudentSeeBelt(0, 1)).toBe(true);
    expect(canStudentSeeBelt(1, 1)).toBe(true);
    expect(canStudentSeeBelt(2, 1)).toBe(false);
  });

  it('resume o progresso ignorando conceitos de fora da lista', () => {
    expect(summarizeProgress(['a', 'b', 'c'], new Set(['a', 'x']))).toEqual({ completed: 1, total: 3, percent: 33 });
    expect(summarizeProgress([], new Set(['a']))).toEqual({ completed: 0, total: 0, percent: 0 });
  });

  it('move um conceito trocando com o vizinho e normaliza posições empatadas', () => {
    const items = [{ id: 'a', position: 0 }, { id: 'b', position: 0 }, { id: 'c', position: 0 }];
    expect(swapPositions(items, 'c', 'up')).toEqual([['c', 1], ['b', 2]]);
    expect(swapPositions(items, 'a', 'up')).toEqual([]);
    expect(swapPositions(items, 'c', 'down')).toEqual([]);
    expect(swapPositions(items, 'zzz', 'down')).toEqual([]);
  });

  it('tem trilha sugerida para as cinco faixas, com as quatro categorias preenchidas', () => {
    expect(STARTER_CURRICULUM).toHaveLength(5);
    for (const belt of STARTER_CURRICULUM) {
      for (const category of TRACK_CATEGORIES) {
        expect(belt[category].length).toBeGreaterThan(0);
        for (const lesson of belt[category]) expect(lesson.title.length).toBeLessThanOrEqual(120);
      }
    }
    expect(starterFor(9)).toBe(STARTER_CURRICULUM[4]);
    expect(starterFor(-1)).toBe(STARTER_CURRICULUM[0]);
  });
});
