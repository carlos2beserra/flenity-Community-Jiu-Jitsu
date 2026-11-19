export type BeltLevel = { id: string; order: number; maxDegrees: number; minClasses: number };
export type CurrentRank = { beltId: string; degree: number };

export function sortBelts<T extends BeltLevel>(belts: T[]): T[] {
  return [...belts].sort((a, b) => a.order - b.order);
}

/**
 * Próxima graduação: sobe um grau até `maxDegrees`; depois troca para a próxima faixa (grau 0).
 * Retorna null se o aluno já está no topo.
 */
export function nextRank(current: CurrentRank, belts: BeltLevel[]): CurrentRank | null {
  const ordered = sortBelts(belts);
  const index = ordered.findIndex((b) => b.id === current.beltId);
  if (index === -1) throw new Error(`Faixa ${current.beltId} não pertence à modalidade`);

  const belt = ordered[index];
  if (current.degree < belt.maxDegrees) return { beltId: belt.id, degree: current.degree + 1 };

  const nextBelt = ordered[index + 1];
  return nextBelt ? { beltId: nextBelt.id, degree: 0 } : null;
}

/** Apto a graduar quando atingiu o mínimo de aulas da faixa atual desde a última promoção. */
export function isEligibleForPromotion(classesSinceLastPromotion: number, belt: Pick<BeltLevel, 'minClasses'>): boolean {
  return classesSinceLastPromotion >= belt.minClasses;
}
