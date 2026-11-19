import { isEligibleForPromotion, nextRank } from './graduation';

const belts = [
  { id: 'azul', order: 1, maxDegrees: 4, minClasses: 80 },
  { id: 'branca', order: 0, maxDegrees: 4, minClasses: 40 },
  { id: 'roxa', order: 2, maxDegrees: 4, minClasses: 100 },
];

describe('nextRank', () => {
  it('sobe um grau dentro da mesma faixa', () => {
    expect(nextRank({ beltId: 'branca', degree: 2 }, belts)).toEqual({ beltId: 'branca', degree: 3 });
  });

  it('troca de faixa após o último grau', () => {
    expect(nextRank({ beltId: 'branca', degree: 4 }, belts)).toEqual({ beltId: 'azul', degree: 0 });
  });

  it('retorna null no topo da modalidade', () => {
    expect(nextRank({ beltId: 'roxa', degree: 4 }, belts)).toBeNull();
  });

  it('falha para faixa de outra modalidade', () => {
    expect(() => nextRank({ beltId: 'preta-judo', degree: 0 }, belts)).toThrow();
  });
});

describe('isEligibleForPromotion', () => {
  it('fica apto ao atingir o mínimo de aulas', () => {
    expect(isEligibleForPromotion(39, { minClasses: 40 })).toBe(false);
    expect(isEligibleForPromotion(40, { minClasses: 40 })).toBe(true);
  });
});
