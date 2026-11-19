import { addMonths, diffInDays, toDateOnly } from './dates';

export type BillableMembership = {
  startDate: Date;
  endDate: Date | null;
  billingCycleMonths: number;
};

/**
 * Retorna a data de vencimento que cai no mês de referência (month: 0-11),
 * ou null se a matrícula não cobra naquele mês.
 */
export function dueDateInMonth(membership: BillableMembership, year: number, month: number): Date | null {
  const start = toDateOnly(membership.startDate);
  const monthsSinceStart = (year - start.getUTCFullYear()) * 12 + (month - start.getUTCMonth());
  if (monthsSinceStart < 0 || monthsSinceStart % membership.billingCycleMonths !== 0) return null;

  const dueDate = addMonths(start, monthsSinceStart);
  if (membership.endDate && dueDate > toDateOnly(membership.endDate)) return null;
  return dueDate;
}

export type InvoiceLike = { status: 'PENDING' | 'PAID' | 'CANCELED'; dueDate: Date };

export function daysOverdue(invoice: InvoiceLike, today: Date): number {
  if (invoice.status !== 'PENDING') return 0;
  return Math.max(0, diffInDays(today, invoice.dueDate));
}

export function isOverdue(invoice: InvoiceLike, today: Date): boolean {
  return daysOverdue(invoice, today) > 0;
}
