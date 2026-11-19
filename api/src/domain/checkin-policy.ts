import { daysOverdue, InvoiceLike } from './billing';

export type CheckInContext = {
  studentStatus: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED';
  modalityId: string;
  activeMemberships: { modalityIds: string[]; weeklyLimit: number | null }[];
  pendingInvoices: InvoiceLike[];
  blockOverdueDays: number;
  checkInsThisWeek: number;
  today: Date;
};

export type CheckInDecision = { allowed: true } | { allowed: false; reason: string };

/** Regras de controle de acesso aplicadas na catraca/recepção. */
export function evaluateCheckIn(ctx: CheckInContext): CheckInDecision {
  if (ctx.studentStatus !== 'ACTIVE') {
    return { allowed: false, reason: 'Aluno não está ativo' };
  }

  const coveringMemberships = ctx.activeMemberships.filter((m) => m.modalityIds.includes(ctx.modalityId));
  if (coveringMemberships.length === 0) {
    return { allowed: false, reason: 'Nenhum plano ativo cobre esta modalidade' };
  }

  const worstDelay = Math.max(0, ...ctx.pendingInvoices.map((inv) => daysOverdue(inv, ctx.today)));
  if (worstDelay > ctx.blockOverdueDays) {
    return { allowed: false, reason: `Mensalidade em atraso há ${worstDelay} dias` };
  }

  const hasUnlimited = coveringMemberships.some((m) => m.weeklyLimit === null);
  const weeklyLimit = Math.max(...coveringMemberships.map((m) => m.weeklyLimit ?? 0));
  if (!hasUnlimited && ctx.checkInsThisWeek >= weeklyLimit) {
    return { allowed: false, reason: `Limite semanal de ${weeklyLimit} aulas atingido` };
  }

  return { allowed: true };
}
