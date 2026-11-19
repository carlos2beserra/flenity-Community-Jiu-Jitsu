import { describe, expect, it } from 'vitest';
import type { Rank } from '../lib/types';
import { latestPerModality } from './StudentDetail';

const rank = (id: string, modalityId: string): Rank => ({
  id, degree: 0, promotedAt: '2026-01-01',
  belt: { id: 'b', name: 'Branca', color: '#fff', order: 0, minClasses: 40, maxDegrees: 4 },
  modality: { id: modalityId, name: modalityId },
});

describe('latestPerModality', () => {
  it('mantém só a graduação mais recente de cada modalidade', () => {
    const result = latestPerModality([rank('r3', 'bjj'), rank('r2', 'muay'), rank('r1', 'bjj')]);
    expect(result.map((r) => r.id)).toEqual(['r3', 'r2']);
  });
});
